#!/bin/bash
#Проверяем root
if [[ $EUID -ne 0 ]]; then
    echo "Этот скрипт нужно запускать с sudo или от root"
    exit 1
fi

apt update > /dev/null
    
#Устанавливаем Python3 и Flask
if ! command -v python3 &>/dev/null; then
    echo "Python3 не найден, устанавливаем..."
    apt install -y -qq python3
fi

if ! python3 -c "import flask" &>/dev/null; then
    echo "Flask не установлен, устанавливаем..."
    apt install -y -qq python3-flask
fi

# =============================================================================
# Переменные
# =============================================================================
# Список серверов Flask
SERVER_NAMES_SOURCE="servers"
# Приложение Python
APP_SOURCE="app.py"
# Имя пользователя
USERNAME="flask"
# Базовые директории
LOG_BASE_DIR="/var/log"
SERVICE_DIR="/opt"
#  лог-файл
LOG_FILE="flask_app.log"
PORT_BASE=5001
# имя сайта
SITE_NAME="mysite.local"
# Путь к сертификатам
SERT_PUB="mysite.local.crt"
SERT_KEY="mysite.local.key"

create_dirs() {
    local name="$1"
    mkdir -p "${SERVICE_DIR}/${name}"
    chown $USERNAME:$USERNAME "${SERVICE_DIR}/${name}"
    chmod 755 "${SERVICE_DIR}/${name}"

    mkdir -p "${LOG_BASE_DIR}/${name}"
    chown $USERNAME:$USERNAME "${LOG_BASE_DIR}/${name}"
    chmod 755 "${LOG_BASE_DIR}/${name}"
}

copy_app() {
    local name="$1"
    sed "s/{SERVER_NAME}/$name/" "$APP_SOURCE" > "${SERVICE_DIR}/${name}/app.py"
    chown $USERNAME:$USERNAME "${SERVICE_DIR}/${name}/app.py"
    chmod 644 "${SERVICE_DIR}/${name}/app.py"
}

create_unit() {
    local name="$1"
    local port="$2"
    UNIT_FILE="/etc/systemd/system/${name}.service"
    
    if [[ -f "$UNIT_FILE" ]]; then
        echo "Сервис $name уже существует"
        exit 1
    fi
    # Создаем systemd unit-файлы
    cat > "$UNIT_FILE" << EOF
[Unit]
Description=My HTTP Application $name
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=simple

ExecStart=/usr/bin/python3 ${SERVICE_DIR}/${name}/app.py
ExecStartPost=/bin/echo "App started successfully"

User=$USERNAME
Group=$USERNAME

WorkingDirectory=${SERVICE_DIR}/${name}

Environment="PORT=${port}"
Environment="PYTHONPATH=${SERVICE_DIR}/${name}"
Environment="LOG_LEVEL=INFO"

Restart=always
RestartSec=5
RestartPreventExitStatus=0 1 2
RestartForceExitStatus=3 4 SIGUSR1

TimeoutStartSec=30
TimeoutStopSec=15

RuntimeMaxSec=infinity

StandardOutput=append:${LOG_BASE_DIR}/${name}/${LOG_FILE}
StandardError=append:${LOG_BASE_DIR}/${name}/${LOG_FILE}

SyslogIdentifier=${name}
LogLevelMax=info

NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true
ProtectHome=true
ProtectSystem=strict
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
ProtectClock=true
ProtectHostname=true

[Install]
WantedBy=multi-user.target
EOF
}

# =============================================================================
# Создаем пользователя
# =============================================================================

if id "$USERNAME" &>/dev/null; then
    echo "Пользователь '$USERNAME' существует." 
else
    useradd -r -M -s /sbin/nologin $USERNAME
fi

# =============================================================================
# Читаем список серверов из файла
# =============================================================================
# Проверяем существование файла SERVER_NAMES_SOURCE
#- `-f` проверяет, что **файл существует** и **это не директория**.
#- `-s` проверяет, что **файл существует и не пустой**.
# if [[ ! -f "$SERVER_NAMES_SOURCE" ]] || [[ ! -s "$SERVER_NAMES_SOURCE" ]]; then


if [[ ! -s "$SERVER_NAMES_SOURCE" ]]; then
	echo "Ошибка чтения файла '$SERVER_NAMES_SOURCE'"
	exit 1
fi

PORT=$PORT_BASE	
SERVER_NAMES=()
PORTS=()
while IFS= read -r SERVER_NAME
do
   [[ -z "$SERVER_NAME" ]] && continue
   SERVER_NAMES+=("$SERVER_NAME")
   PORTS+=("$((PORT++))")
done < "$SERVER_NAMES_SOURCE"

#Проверяем что файл приложения существует и не пустой
if [[ ! -s "$APP_SOURCE" ]]; then
   echo "Ошибка чтения файла '$APP_SOURCE'"
   exit 1
fi

# =============================================================================
# Создаем директории для проекта и логов, копируем код приложения
# =============================================================================
for i in "${!SERVER_NAMES[@]}"
do
   NAME="${SERVER_NAMES[$i]}"
   PORT="${PORTS[$i]}"
   
   create_dirs "$NAME"
   copy_app "$NAME"
   create_unit "$NAME" "$PORT"
done

# -----------------------------------------------------------------------------
# Обновляем systemd
# -----------------------------------------------------------------------------
systemctl daemon-reload

# -----------------------------------------------------------------------------
# Включаем автозапуск и запускаем все сервисы
# -----------------------------------------------------------------------------
for NAME in "${SERVER_NAMES[@]}"; do
    systemctl enable "${NAME}.service"
    systemctl start "${NAME}.service"
    echo "Сервис ${NAME}.service запущен и включен в автозагрузку."
done

# -----------------------------------------------------------------------------
# Установка и настройка Nginx
# -----------------------------------------------------------------------------

#Устанавливаем Nginx
if ! command -v nginx &>/dev/null; then
    echo "Nginx не найден, устанавливаем..."
    apt install -y -qq nginx
fi

# Копируем фалы сертификата в /etc
cp "$SERT_PUB" /etc/ssl/certs/
cp "$SERT_KEY" /etc/ssl/private/

chmod 644 "/etc/ssl/certs/${SERT_PUB}"
chown root:root "/etc/ssl/certs/${SERT_PUB}"

chmod 640 "/etc/ssl/private/${SERT_KEY}"
chown root:ssl-cert "/etc/ssl/private/${SERT_KEY}"


# Создаем конфиг для сайта
# Формируем блок upstream
UPSTREAM_BLOCK="upstream flask_backend {\n"
for port in "${PORTS[@]}"; do
    UPSTREAM_BLOCK+="    server 127.0.0.1:${port};\n"
done
UPSTREAM_BLOCK+="}\n"

# Преобразуем управляющие последовательности (\n → реальные переводы строк)
printf -v UPSTREAM_BLOCK "%b" "$UPSTREAM_BLOCK"

# Создаём конфиг Nginx
cat > "/etc/nginx/sites-available/$SITE_NAME" << EOF
${UPSTREAM_BLOCK}

server {
    listen 443 ssl;
    server_name ${SITE_NAME} localhost;

    ssl_certificate     /etc/ssl/certs/${SERT_PUB};
    ssl_certificate_key /etc/ssl/private/${SERT_KEY};

    access_log /var/log/nginx/${SITE_NAME}.access.log;
    error_log  /var/log/nginx/${SITE_NAME}.error.log;

    location / {
        proxy_pass http://flask_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        add_header X-Backend-Server \$upstream_addr;
    }
}
EOF


# делаем линк в sites-enable
ln -sf "/etc/nginx/sites-available/${SITE_NAME}" "/etc/nginx/sites-enabled/${SITE_NAME}"

if [[ -L "/etc/nginx/sites-enabled/${SITE_NAME}" ]]; then
    echo "Линк создан."
else
    echo "Ошибка добавления в sites-enabled."
fi




# Проверка конфигурации
if nginx -t; then
    echo "Конфигурация Nginx корректна, перезапускаем сервис..."
    systemctl reload nginx
else
    echo "Ошибка конфигурации Nginx! Исправьте ошибки перед запуском."
    exit 1
fi





[Interface]
Address = 192.168.100.16/24
ListenPort = 51820
PrivateKey = mFlFggmbHK3pC4ldvp0tyWHbhWNZhysIfG73xkg8x1U=

PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = 4tEBbFBbwuPpCWTlhZ/uXFtLTUJNnz7W7k7KnMB+/GM=
AllowedIPs = 192.168.100.15/32