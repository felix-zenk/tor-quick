#!/usr/bin/env sh

HIDDEN_SERVICE_DIR=$(realpath "${HIDDEN_SERVICE_DIR:-/var/lib/tor/hidden_service}")
DATA_DIR=$(realpath "${DATA_DIR:-/var/lib/tor}")
LOG_DIR=$(realpath "${LOG_DIR:-/var/log/tor}")

if ! env | grep -qE '^FORWARD_ADDR\d*='; then
  echo "[ERROR]: No forwards found! Set FORWARD_ADDR or any FORWARD_ADDRx where x is a number."
  exit 1
fi

mkdir -p "${HIDDEN_SERVICE_DIR}" "${DATA_DIR}" "${LOG_DIR}"
if ! [ -f "${LOG_DIR}" ]; then
  touch "${LOG_DIR}/notices.log"
fi
chmod -R 700 "${HIDDEN_SERVICE_DIR}"
chown -R tor:nogroup "${DATA_DIR}" "${LOG_DIR}/notices.log"


HIDDEN_SERVICES=""  # List of services to be displayed at the end
USED_PORTS=""  # List of ports that are already in use

TORRC="Log notice file ${LOG_DIR}/notices.log
DataDirectory ${DATA_DIR}

HiddenServiceDir ${HIDDEN_SERVICE_DIR}
"

# Get all environment variables that match FORWARD_ADDR(+number)
for varname in $(env | grep -E '^FORWARD_ADDR\d*=' | sed 's/=.*//'); do
  # Get the value of the environment variable
  value="$(eval echo \$"$varname")"

  # If value matches the legacy format prepend 80: to the value
  if echo "$value" | grep -qE '^[[:alnum:].]+:\d+$'; then
    echo "[WARNING]: Legacy format detected: Please change $value (in $varname) to 80:$value"
    value="80:$value"
  fi

  # Parse the listening port
  PORT=$(echo "$value" | cut -d ':' -f1)
  if ! echo "$PORT" | grep -qE '^\d+$'; then
    echo "[ERROR]: Invalid port number: $PORT (in $varname)
Define a valid port number in the format PORT:FWD_ADDR or PORT:FWD_ADDR:FWD_PORT"
    exit 1
  fi

  # Check if the port is already in use
  for used_port in $USED_PORTS; do
    if [ "$PORT" = "$used_port" ]; then
      echo "[ERROR]: Port $PORT was already defined in another environment variable! Can not be used in $varname"
    exit 1
    fi
  done
  USED_PORTS="${USED_PORTS} $PORT"

  # Parse the forward address and add the same port if only the listening port is defined
  FORWARD_ADDRESS=$(echo "$value" | cut -d ':' -f2-)
  if ! echo "$FORWARD_ADDRESS" | grep -qE ':\d+$'; then
    FORWARD_ADDRESS="${FORWARD_ADDRESS}:${PORT}"
  fi

  # If environment variable CHECK_DESTINATION is set, check if the destination is reachable
  if [ -n "$CHECK_DESTINATION" ]; then
    if ! nc -z -w 1 "$(echo "$FORWARD_ADDRESS" | cut -d ':' -f1)" "$(echo "$FORWARD_ADDRESS" | cut -d ':' -f2)"; then
      echo "[ERROR]: Destination is unreachable: $FORWARD_ADDRESS (in $varname)"
      exit 1
    fi
  fi

  # Add the service to the list to be displayed later
  HIDDEN_SERVICES="${HIDDEN_SERVICES} ${PORT}~${FORWARD_ADDRESS}"

  # Add the service to the torrc configuration
  TORRC="${TORRC}HiddenServicePort $PORT $FORWARD_ADDRESS
"
done

# Generate and check the torrc configuration
if [ -n "$TORRC_EXTRA" ]; then
  TORRC="${TORRC}
${TORRC_EXTRA}
"
fi
if [ -n "$ENABLE_VANGUARDS" ]; then
  # If ControlPort is not yet present in TORRC, then enable the default control port
  if ! echo "$TORRC" | grep -qE '^ControlPort \d+'; then
    TORRC="${TORRC}
ControlPort 9051
"
  fi

  # If there is no verification option enabled, then enable CookieAuthentication
  if ! echo "${TORRC}" | grep -qE '^CookieAuthentication 1|HashedControlPassword \d+:\w+'; then
    TORRC="${TORRC}
CookieAuthentication 1
"
  fi
fi
echo "$TORRC" > /etc/tor/torrc
if ! su -s /bin/sh -c '/usr/bin/tor --verify-config > /dev/null 2>&1' tor; then
  echo "[ERROR]: Invalid torrc configuration"
  exit 1
fi
echo "[INFO]: torrc is valid"

# Start tor as a background process as the tor user
su -s /bin/sh -c '/usr/bin/tor' tor &

# If enabled, start vanguards as a background process as the tor user
if [ -n "$ENABLE_VANGUARDS" ]; then
  CONTROL_PORT=$(grep -E '^ControlPort \d+' /etc/tor/torrc | tail -n1 | cut -d ' ' -f2)
  until [ -f "${DATA_DIR}/cached-microdesc-consensus" ]; do
    sleep .1
  done
  su -s /bin/sh -c "cd /opt/vanguards && python3 /opt/vanguards/src/vanguards.py --control_port ${CONTROL_PORT}" tor &
fi

# Wait for the hidden service to be generated if it doesn't exist
until [ -f "${HIDDEN_SERVICE_DIR}/hostname" ]; do
  sleep .1
done

# Display the onion service address and the hidden services
ONION_SERVICE_ADDRESS="$(cat "${HIDDEN_SERVICE_DIR}/hostname")"
echo "[INFO]: Onion Service address: $ONION_SERVICE_ADDRESS"
for service in $HIDDEN_SERVICES; do
  PORT=$(echo "$service" | cut -d '~' -f1)
  FORWARD_ADDRESS=$(echo "$service" | cut -d '~' -f2)
  echo "[INFO]: Hidden service: $ONION_SERVICE_ADDRESS:$PORT -> $FORWARD_ADDRESS"
done

# Wait for the log file to be created
until [ -f "${LOG_DIR}/notices.log" ]; do
  sleep .1
done

# Display the logs
exec tail -f "${LOG_DIR}/notices.log"
