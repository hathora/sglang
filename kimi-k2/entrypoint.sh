#!/bin/bash
set -e

# Environment setup
export SGL_DG_CACHE_DIR=/cache
export SGLANG_DG_CACHE_DIR=/cache
export DG_JIT_CACHE_DIR=/cache
export HF_HOME=/cache
export CONTEXT_LENGTH=${CONTEXT_LENGTH:-8192}
export QUANTIZATION=${QUANTIZATION:-fp8}

# Configuration
MODEL_PATH="moonshotai/Kimi-K2-Instruct"
MASTER_PORT=20000
HTTP_PORT=${HTTP_PORT:-25000}
API_KEY="${API_KEY:-${HATHORA_APP_SECRET:-}}"

# Determine IB interfaces
IB_IFACES=""
for d in $(ibstat | grep -i "Active" -B 8 | grep -E "^CA" | awk '{ print $2 }' | sed "s/'//g"); do
  if [[ -d "/sys/class/infiniband/$d/device/net" ]]; then
    for n in $(ls "/sys/class/infiniband/$d/device/net"); do
      IB_IFACES+="${IB_IFACES:+,}$n"
    done
  fi
done

echo "$IFACES"

export NCCL_SOCKET_IFNAME=${NCCL_SOCKET_IFNAME:-$IFACES}
export GLOO_SOCKET_IFNAME=${GLOO_SOCKET_IFNAME:-$IFACES}

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
  SERVER_ARGS="--host 0.0.0.0 --port $HTTP_PORT --api-key $API_KEY"
else
  # Secondary node
  MASTER_IP=$(python3 -c "import json,os; print(json.loads(os.environ['HATHORA_INITIAL_ROOM_CONFIG'])['master_ip'])")
  NODE_RANK=1
  SERVER_ARGS=""
fi

# Launch SGLang server
exec python3 -m sglang.launch_server \
  --model-path "$MODEL_PATH" \
  --tp 16 \
  --dist-init-addr "$MASTER_IP:$MASTER_PORT" \
  --nnodes 2 \
  --node-rank $NODE_RANK \
  --context-length $CONTEXT_LENGTH \
  --quantization $QUANTIZATION \
  --trust-remote-code \
  --tool-call-parser kimi_k2 \
  $SERVER_ARGS \
  2>&1
