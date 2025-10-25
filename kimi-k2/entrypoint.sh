#!/bin/bash
set -e

# Environment setup
export SGL_DG_CACHE_DIR=/cache/2
export SGLANG_DG_CACHE_DIR=/cache/2
export DG_JIT_CACHE_DIR=/cache/2
export HF_HOME=/cache/2
# export SGLANG_ALLOW_OVERWRITE_LONGER_CONTEXT_LEN=1

# Configuration
export MODEL_PATH="moonshotai/Kimi-K2-Instruct"
export MASTER_PORT=20000
export PORT=${PORT:-25000}
export API_KEY="${API_KEY:-${HATHORA_APP_SECRET:-}}"

# Tunables (env override friendly)
export CONTEXT_LENGTH=${CONTEXT_LENGTH:-131072}           # e.g. 131072 for K2 max
export MEM_FRACTION_STATIC=${MEM_FRACTION_STATIC:-0.70} # e.g. 0.70–0.80 recommended
export QUANTIZATION=${QUANTIZATION:-fp8}

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
  MASTER_IP=$HATHORA_PRIVATE_IP
  NODE_RANK=0
  python3 create_hathora_room.py "$MASTER_IP"
  SERVER_ARGS="--host 0.0.0.0 --port $PORT --api-key $API_KEY"
else
  # Secondary node
  MASTER_IP=$(python3 -c "import json,os; print(json.loads(os.environ['HATHORA_INITIAL_ROOM_CONFIG'])['master_ip'])")
  NODE_RANK=1
  SERVER_ARGS=""
fi

# if DEBUG is set, then start a netcat listener on port
if [ -n "$DEBUG" ]; then
  while true; do
    nc -l -p $PORT
    echo "Received request"
    sleep 1
  done
fi

# Launch SGLang server
exec python3 -m sglang.launch_server \
  --model-path "$MODEL_PATH" \
  --tp 16 \
  --dist-init-addr "$MASTER_IP:$MASTER_PORT" \
  --nnodes 2 \
  --node-rank $NODE_RANK \
  --context-length "$CONTEXT_LENGTH" \
  --mem-fraction-static "$MEM_FRACTION_STATIC" \
  --quantization "$QUANTIZATION" \
  --trust-remote-code \
  --tool-call-parser kimi_k2 \
  $SERVER_ARGS \
  2>&1
