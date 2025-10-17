#!/bin/bash
set -e

# Environment setup
export SGLANG_DG_CACHE_DIR=/cache
export DG_JIT_CACHE_DIR=/cache
export HF_HOME=/cache
export NCCL_SOCKET_IFNAME=ens6
export GLOO_SOCKET_IFNAME=ens6

# Configuration
MODEL_PATH="moonshotai/Kimi-K2-Instruct"
MASTER_PORT=20000
HTTP_PORT=${HTTP_PORT:-8000}

# Determine node role
if [ -z "$HATHORA_INITIAL_ROOM_CONFIG" ]; then
  # Primary node
  MASTER_IP=$HATHORA_PRIVATE_IP
  NODE_RANK=0
  python3 create_hathora_room.py "$MASTER_IP"
  SERVER_ARGS="--host 0.0.0.0 --port $HTTP_PORT"
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
  --trust-remote-code \
  --tool-call-parser kimi_k2 \
  $SERVER_ARGS \
  2>&1
