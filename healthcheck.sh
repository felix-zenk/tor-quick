#!/bin/sh

# Check if tor is running
if ! ps -o user,args | grep -qE "^tor\s+/usr/bin/tor"; then
  echo "[ERROR]: Tor is not running"
  exit 1
fi
echo "[INFO]: Tor is running"

# Check if vanguards is running
if [ -n "$ENABLE_VANGUARDS" ]; then
  if ! ps -o user,args | grep -qE "^tor\s+python3 /opt/vanguards/src/vanguards.py"; then
    echo "[ERROR]: Vanguards is not running"
    exit 1
  fi
  echo "[INFO]: Vanguards is running"
fi

exit 0
