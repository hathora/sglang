#!/bin/bash

# Common environment variables for all nodes
export SGLANG_DG_CACHE_DIR=/cache
export DG_JIT_CACHE_DIR=/cache
export HF_HOME=/cache

export NCCL_SOCKET_IFNAME=ens6
export GLOO_SOCKET_IFNAME=ens6

# start the kimi server
python3 start_kimi.py
