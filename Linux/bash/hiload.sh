#!/usr/bin/env bash
CPU_WORKERS=4      
MEM_MB=512         
DISK_MB=512        
DISK_FILE="/tmp/stress_disk.img"

CPU_PIDS=()
MEM_PIDS=()
DD_PID=""

cleanup() {
  echo "Останавливаю стресс-нагрузку..."
  for p in "${CPU_PIDS[@]}" "${MEM_PIDS[@]}"; do
    kill "$p" 2>/dev/null || true
  done
  [ -n "$DD_PID" ] && kill "$DD_PID" 2>/dev/null || true
  rm -f "$DISK_FILE"
  echo "Готово."
}
trap cleanup EXIT INT TERM

# --- CPU ---
for i in $(seq 1 $CPU_WORKERS); do
  ( while :; do :; done ) &
  CPU_PIDS+=($!)
done

# --- память ---
python3 - <<PY &
import time, sys
blocks=[]
try:
    for _ in range(int(${MEM_MB})):
        blocks.append(' ' * 1024 * 1024)  # ~1MB
    time.sleep(86400)  # держим сутки, пока не убьют
except MemoryError:
    sys.exit(0)
PY
MEM_PIDS+=($!)

# --- диск ---
dd if=/dev/zero of="$DISK_FILE" bs=1M count=$DISK_MB oflag=direct status=none &
DD_PID=$!

echo "Нагрузка запущена: CPU=${CPU_WORKERS}, MEM=${MEM_MB}MB, DISK=${DISK_MB}MB"
echo "Для остановки — нажмите Ctrl+C или выполните: kill $$"
wait