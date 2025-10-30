#!/bin/bash
LOGFILE="./backup.log"
DEST="./backups" 
SOURCE=./sourcedir

mkdir -p "$DEST"

DATE=$(date +%Y-%m-%d_%H-%M-%S)
ARCHIVE_NAME="backup_${DATE}.tar.gz"

if [[ -f "${DEST}/${ARCHIVE_NAME}" ]]; then
    echo "Архив ${ARCHIVE_NAME} уже существует" >&2
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') Начинаем резервное копирование ${SOURCE}" >> "$LOGFILE"

tar --listed-incremental="$DEST/snapshot.snar" -czf "$DEST/$ARCHIVE_NAME" -C "$SOURCE" .

if [[ $? -eq 0 ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Архив успешно создан: ${DEST}/${ARCHIVE_NAME}" >> "$LOGFILE"
else
    echo "Ошибка при создании архива" >&2
    exit 1
fi

md5sum "${DEST}/${ARCHIVE_NAME}" > "${DEST}/${ARCHIVE_NAME}.md5"
echo "$(date '+%Y-%m-%d %H:%M:%S') MD5 создан: ${DEST}/${ARCHIVE_NAME}.md5" >> "$LOGFILE"

# Добавляем права на выполнение
# chmod +x backup.sh
# Добавляем автозапуск в cron каждый день в 1-00
# crontab -e
# 0 1 * * * /home/user/backup.sh
#