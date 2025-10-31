#!/bin/bash
LOG_DIR="./logs"
DEBUG=0
INTERVAL=60
KEEP_DAYS=3

timestamp() {
date -u +"%Y-%m-%d_%H:%M:%S"
}

rotate_logs() {
  mkdir -p "${LOG_DIR}"
  find "${LOG_DIR}" -type f -name "*.log" -mtime +$((KEEP_DAYS-1)) -print -delete || true
}

log_path() {
local tdate
tdate=$(date -u +"%Y-%m-%d")
echo "${LOG_DIR}/monitor_${tdate}.log"
}

err_path() {
local tdate
tdate=$(date -u +"%Y-%m-%d")
echo "${LOG_DIR}/monitor_${tdate}.err.log"
}

cleanup() {
echo "$(timestamp) [INFO] Получен сигнал $1, Завершение работы." >> "$(log_path)"
pkill -P $$ 2>/dev/null || true
exit 0
}

printhelp() {
  cat << EOF
Системный мониторинг с ротацией логов.

OPTIONS:
    -d, --debug      Включить отладочный режим
    -i, --interval   Интервал проверки в секундах (по умолчанию: 60)
    -h, --help       Показать эту справку

Примеры:
    $0                   # Запуск с интервалом 60 секунд
    $0 -d -i 30          # Отладочный режим, интервал 30 секунд
    $0 --interval 300    # Интервал 5 минут

Логи сохраняются в: $LOG_DIR
EOF
  exit 0
}

check() {
  {
    echo "$(timestamp) [INFO] SYSTEM MONITORING REPORT"
    echo "--- CPU Usage ---"
    top -bn1 | head -3
    echo "--- Memory Usage ---"
    free -h
    echo "--- Disk Usage ---"
    df -h
    echo "--- END OF REPORT ---"
    echo ""
  } >> "$(log_path)" 2>> "$(err_path)"
}

trap 'cleanup SIGINT' SIGINT
trap 'cleanup SIGTERM' SIGTERM

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--debug)
      DEBUG=1
      ;;
    -i|--interval)
      shift
      INTERVAL=$1
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

while true; do
  rotate_logs
  check
  sleep "$INTERVAL"
done
