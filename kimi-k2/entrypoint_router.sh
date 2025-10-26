#!/bin/bash
set -e

# setup cache directories
export SGL_DG_CACHE_DIR=/cache/2
export SGLANG_DG_CACHE_DIR=/cache/2
export DG_JIT_CACHE_DIR=/cache/2
export HF_HOME=/cache/2

#additional server arguments
export MASTER_PORT=20000
export PORT=${PORT:-30000}
export API_KEY="${API_KEY:-${HATHORA_APP_SECRET:-}}"

# Determine IB interfaces
IB_IFACES=""
for d in $(ibstat | grep -i "Active" -B 8 | grep -E "^CA" | awk '{ print $2 }' | sed "s/'//g"); do
  if [[ -d "/sys/class/infiniband/$d/device/net" ]]; then
    for n in $(ls "/sys/class/infiniband/$d/device/net"); do
      echo "Enabling IB interface: $n"
      ip link set "$n" up 2>/dev/null || echo "Failed to bring up $n"
      IB_IFACES+="${IB_IFACES:+,}$n"
    done
  fi
done

echo "Enabled IB interfaces: $IB_IFACES"
echo "$IB_IFACES"

export NCCL_SOCKET_IFNAME=${NCCL_SOCKET_IFNAME:-$IB_IFACES}
export GLOO_SOCKET_IFNAME=${GLOO_SOCKET_IFNAME:-$IB_IFACES}

if [[ -z "$NCCL_SOCKET_IFNAME" || -z "$GLOO_SOCKET_IFNAME" ]]; then
  echo "No active IB interfaces found. Exiting."
  exit 1
fi

# Determine node role
if [ -z "$HATHORA_INITIAL_ROOM_CONFIG" ]; then
  # Primary node
  export MASTER_IP=$HATHORA_PRIVATE_IP
  export NODE_RANK=0
  python3 create_hathora_room.py "$MASTER_IP"
else
  # Secondary node
  export MASTER_IP=$(python3 -c "import json,os; print(json.loads(os.environ['HATHORA_INITIAL_ROOM_CONFIG'])['master_ip'])")
  export NODE_RANK=1
fi

# check PRESET and if the preset file exists
if [ -z "$PRESET" ]; then
  echo "PRESET is not set"
  exit 1
elif [ ! -f "presets/$PRESET.template" ]; then
  echo "Preset file presets/$PRESET.template not found"
  echo "Available presets: $(ls presets/*.template)"
  exit 1
fi

# if DEBUG is set, then start a netcat listener on port
if [ -n "$DEBUG" ]; then
  while true; do
    nc -l -p $PORT
    echo "Received request"
    sleep 1
  done
fi

# unwrap the arguments from the template file and pass them to the launch_server command
export args=$(envsubst < presets/$PRESET.template | tr '\n' ' ')
echo "sglang_router.launch_server arguments: $args"

# launch the server
exec python3 -m sglang_router.launch_server $args 2>&1