#!/usr/bin/env sh

HIDDEN_SERVICE_DIR=$(realpath "${HIDDEN_SERVICE_DIR:-/var/lib/tor/hidden_service}")
DATA_DIR=$(realpath "${DATA_DIR:-/var/lib/tor}")
LOG_DIR=$(realpath "${LOG_DIR:-/var/log/tor}")

mkdir -p "${HIDDEN_SERVICE_DIR}" "${DATA_DIR}" "${LOG_DIR}"
chown "${USER:-$(whoami)}": "${HIDDEN_SERVICE_DIR}"
chmod 700 "${HIDDEN_SERVICE_DIR}"

echo "Log notice file ${LOG_DIR}/notices.log
DataDirectory ${DATA_DIR}
HiddenServiceDir ${HIDDEN_SERVICE_DIR}
HiddenServicePort ${PUBLIC_PORT} ${FORWARD_ADDR}
" > /etc/tor/torrc

tor &

until [ -f "${HIDDEN_SERVICE_DIR}/hostname" ]; do
  sleep 1
done
echo "Hidden service address: $(cat "${HIDDEN_SERVICE_DIR}/hostname")"

until [ -f "${LOG_DIR}/notices.log" ]; do
  sleep 1
done
tail -f "${LOG_DIR}/notices.log"
