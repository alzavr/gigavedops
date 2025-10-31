#!/bin/bash
if [[ $EUID -ne 0 ]]; then
    echo "Этот скрипт нужно запускать с правами root"
    exit 1
fi

LOG_DIR="./logs"
DEBUG=0
DATE=$(date +%Y-%m-%d_%H-%M-%S)
DEFAULT_PASSWORD="password"

printhelp() {
  cat << EOF
Скрипт для массового управления пользователями.

OPTIONS:
    -d, --debug        Включить отладочный режим
    -c, --create       Создание пользователей из указанного CSV файла
    -r, --remove       Удаление пользователей из указанного CSV файла
    -R, --remove-home  При удалении пользователей так же удалить домашнюю директорию
    -h, --help         Показать эту справку

Примеры:
    $0 -d -c userlist.csv    # Режим отладки, создать пользователей, указанных в файле userlist.csv
    $0 -r userstodel.csv     # Удалить пользователей, указанных в файле userstodel.csv
    $0 -r userstodel.csv -R  # Удалить пользователей и их домашние директории

Логи сохраняются в: $LOG_DIR
EOF
  exit 0
}


create_user() {
   local username=$1
   local full_name=$2
   useradd -m -s /sbin/bash -d /home/$username -c "$full_name" $username
   echo "$username:$DEFAULT_PASSWORD" | chpasswd


   runuser -l "$username" -c "mkdir -p /home/${username}/.ssh && ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ''"

   chown -R "$username:$username" "/home/$username/.ssh"
   chmod 700 "/home/$username/.ssh"
   chmod 600 "/home/$username/.ssh/id_rsa"
   chmod 644 "/home/$username/.ssh/id_rsa.pub"
   echo "[INFO] Создан пользователь ${full_name}. Имя пользоваеля: '${username}'" >> "$LOG_PATH"
}

add_role() {
   local username=$1
   local group=$2

    if [[ -z "$group" ]]; then
        echo "[WARN] пустое имя группы для пользователя '$username', пропускаем" >> "$LOG_PATH"
        return
    fi

    if ! getent group "$group" >/dev/null; then
        groupadd "$group"
        echo "[INFO] Создана группа '$group'" >> "$LOG_PATH"
    fi

    if id -nG "$username" | grep -qw "$group"; then
        echo "[INFO] Пользователь $username уже в группе $group" >> "$LOG_PATH"
    else
        usermod -aG "$group" "$username"
        echo "[INFO] Пользователь '$username' добавлен в группу '$group'" >> "$LOG_PATH"
    fi
}

create_users() {
    echo "[INFO] Создание пользователей из списка '$USER_LIST'" >> "$LOG_PATH"
    if [[ ! -s "$USER_LIST" ]]; then
	    echo "[ERROR] Ошибка чтения списка пользователей '$USER_LIST'" >> "$LOG_PATH"
	    return
    fi

    while IFS=, read -r username full_name role; do
        username=$(echo "$username" | xargs)
        full_name=$(echo "$full_name" | xargs)
        role=$(echo "$role" | xargs)
        echo "User='$username', Full='$full_name', Role='$role'"

        if [[ -z "$username" ]]; then
             echo "[WARN] пустое имя пользователя '$full_name', пропускаем" >> "$LOG_PATH"
             continue
        fi

        if id "$username" &>/dev/null; then
             echo "[WARN]Пользователь '$username' уже существует, пропускаем." >> "$LOG_PATH"
             add_role $username $role
        else
            create_user $username $full_name
            add_role $username $role
        fi

    done < $USER_LIST
}

delete_users() {
    echo "[INFO] Удаление пользователей из списка '$USER_LIST_DEL'" >> "$LOG_PATH"

    if [[ ! -s "$USER_LIST_DEL" ]]; then
        echo "[ERROR] Ошибка чтения списка пользователей '$USER_LIST_DEL'" >> "$LOG_PATH"
        return
    fi

    while IFS=, read -r username _; do
        username=$(echo "$username" | xargs)
        if [[ -z "$username" ]]; then
            echo "[WARN] Пустое имя пользователя в списке удаления, пропускаем" >> "$LOG_PATH"
            continue
        fi

        if id "$username" &>/dev/null; then
            CMD="userdel"
            [[ "$REMOVE_HOME" -eq 1 ]] && CMD+=" -r"
            
            if $CMD "$username" 2>>"$LOG_PATH"; then
                echo "[INFO] Пользователь '$username' удален" >> "$LOG_PATH"
            else
                echo "[ERROR] Не удалось удалить пользователя '$username'" >> "$LOG_PATH"
            fi
        else
            echo "[WARN] Пользователь '$username' не найден, пропускаем" >> "$LOG_PATH"
        fi
    done < "$USER_LIST_DEL"  
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--debug)
      DEBUG=1
      ;;
    -c|--create)
      shift
      USER_LIST=$1
      ;;
    -r|--remove)
      shift
      USER_LIST_DEL=$1
      ;;
    -R|--remove-home)
      REMOVE_HOME=1
      ;;
    -h|--help)
      printhelp
      ;;
    *)
      echo "Неизвестный параметр: $1"
      printhelp
      ;;
  esac
  shift
done

if [[ "$DEBUG" -eq 1 ]]; then
set -x
fi

mkdir -p "${LOG_DIR}"
LOG_PATH="${LOG_DIR}/usermanagment_${DATE}.log"

if [[ ! -z "$USER_LIST" ]]; then
    create_users
fi


if [[ ! -z "$USER_LIST_DEL" ]]; then
    delete_users
fi
