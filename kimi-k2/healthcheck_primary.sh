#!/bin/bash

# Health check script for secondary node
# Monitors primary node and terminates if primary becomes unavailable

MASTER_IP=$1
HTTP_PORT=$2
FAILURES=0
MAX_FAILURES=3
CHECK_INTERVAL=5

while sleep $CHECK_INTERVAL; do
  if ! timeout 3 nc -z $MASTER_IP $HTTP_PORT; then
    ((FAILURES++))
    echo "Primary health check failed ($FAILURES/$MAX_FAILURES)"
    if [ $FAILURES -ge $MAX_FAILURES ]; then
      echo "Primary node unavailable, terminating secondary"
      kill 1
      exit 1
    fi
  else
    if [ $FAILURES -gt 0 ]; then
      echo "Primary health check recovered"
    fi
    FAILURES=0
  fi
done
