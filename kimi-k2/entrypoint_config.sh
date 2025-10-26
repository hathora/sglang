#!/bin/bash
set -e

# setup cache directories
export SGL_DG_CACHE_DIR=/cache
export SGLANG_DG_CACHE_DIR=/cache
export DG_JIT_CACHE_DIR=/cache
export HF_HOME=/cache

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

#additional server arguments
export MASTER_PORT=20000
export PORT=${PORT:-30000}
export API_KEY="${API_KEY:-${HATHORA_APP_SECRET:-}}"

# read the preset file based on the environment variable PRESET
if [ -z "$PRESET" ]; then
  echo "PRESET is not set"
  exit 1
fi

# make sure the preset file exists inside the presets directory
if [ ! -f "presets/$PRESET.yaml" ]; then
  echo "Preset file presets/$PRESET.yaml not found"
  echo "Available presets: $(ls presets/*.yaml)"
  exit 1
fi

# render the preset file
cat presets/$PRESET.yaml | envsubst > config.yaml

# print the config file
echo "Generated config file:"
cat config.yaml
echo ""

# if DEBUG is set, then start a netcat listener on port
if [ -n "$DEBUG" ]; then
  while true; do
    nc -l -p $PORT
    echo "Received request"
    sleep 1
  done
fi

# launch the server
exec python3 -m sglang.launch_server --config config.yaml 2>&1