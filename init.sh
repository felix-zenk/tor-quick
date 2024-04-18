#!/usr/bin/env sh

HIDDEN_SERVICE_DIR=$(realpath "${HIDDEN_SERVICE_DIR:-/var/lib/tor/hidden_service}")
DATA_DIR=$(realpath "${DATA_DIR:-/var/lib/tor}")
LOG_DIR=$(realpath "${LOG_DIR:-/var/log/tor}")

if ! env | grep -qE '^FORWARD_ADDR\d*='; then
  echo "No forwards found! Set FORWARD_ADDR or any FORWARD_ADDRx where x is a number."
  exit 1
fi

mkdir -p "${HIDDEN_SERVICE_DIR}" "${DATA_DIR}" "${LOG_DIR}"
chown "${USER:-$(whoami)}": "${DATA_DIR}" "${HIDDEN_SERVICE_DIR}"
chmod -R 700 "${DATA_DIR}" "${HIDDEN_SERVICE_DIR}"

services=""  # List of services to be displayed at the end

TORRC="Log notice file ${LOG_DIR}/notices.log
DataDirectory ${DATA_DIR}
HiddenServiceDir ${HIDDEN_SERVICE_DIR}
"

# Get all environment variables that match FORWARD_ADDR(+number)
for varname in $(env | grep -E '^FORWARD_ADDR\d*=' | sed 's/=.*//'); do
  # Get the value of the environment variable
  value="$(eval echo \$$varname)"

  # Parse the listening port
  PORT=$(echo "$value" | cut -d: -f1)
  if ! echo "$PORT" | grep -qE '^\d+$'; then
    echo "Invalid port number: $PORT (in $varname)
Define a valid port number in the format PORT:FWD_ADDR or PORT:FWD_ADDR:FWD_PORT"
    exit 1
  fi

  # Parse the forward address and add the same port if only the listening port is defined
  FORWARD_ADDRESS=$(echo "$value" | cut -d: -f2-)
  if ! echo "$FORWARD_ADDRESS" | grep -qE ':\d+$'; then
    FORWARD_ADDRESS="${FORWARD_ADDRESS}:${PORT}"
  fi

  # Add the service to the list to be displayed later
  services="${services} ${PORT}~${FORWARD_ADDRESS}"

  # Add the service to the torrc configuration
  TORRC="${TORRC}HiddenServicePort $PORT $FORWARD_ADDRESS
"
done

# Generate and check the torrc configuration
echo "$TORRC" > /etc/tor/torrc
if ! tor --verify-config; then
  echo "Invalid torrc configuration"
  exit 1
fi
tor &

# Wait for the hidden service to be generated if it doesn't exist
until [ -f "${HIDDEN_SERVICE_DIR}/hostname" ]; do
  sleep 1
done

# Display the hidden service address and the services
SERVICE_HOSTNAME="$(cat "${HIDDEN_SERVICE_DIR}/hostname")"
echo "Hidden service address: $SERVICE_HOSTNAME"
for service in $services; do
  PORT=$(echo "$service" | cut -d~ -f1)
  FORWARD_ADDR=$(echo "$service" | cut -d~ -f2)
  echo "Hidden service: $SERVICE_HOSTNAME:$PORT -> $FORWARD_ADDR"
done

# Wait for the log file to be created
until [ -f "${LOG_DIR}/notices.log" ]; do
  sleep 1
done

# Display the logs
exec tail -f "${LOG_DIR}/notices.log"
