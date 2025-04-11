#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
# Exit if unset variables are used.
# Prevent errors in a pipeline from being masked.
set -euo pipefail

# Basic smoke test for the ephemeral deployment - simplified

LOG_FILE="ephemeral-logs.txt"
RETRY_INTERVAL=5
MAX_RETRIES=3
NAMESPACE="default"
LABEL_SELECTOR="app.kubernetes.io/instance=ephemeral-hello,app.kubernetes.io/color=blue"
EXPECTED_LOG="Hello World"

echo "--- Starting Simplified Ephemeral Check ---"

log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

# 1. Attempt to get pod name
POD_NAME=$(kubectl get pods -l "$LABEL_SELECTOR" -n "$NAMESPACE" -o jsonpath="{.items[0].metadata.name}" --ignore-not-found)

if [ -z "$POD_NAME" ]; then
  log "❌ Failure: Could not find running pod name matching labels '$LABEL_SELECTOR'."
  log "Listing all pods in namespace '$NAMESPACE'..."
  kubectl get pods -n "$NAMESPACE"
  exit 1
fi
log "Found pod: $POD_NAME. Checking logs..."

# 2. Check logs for expected output with retries
found_log=false
for ((i=1; i<=MAX_RETRIES; i++)); do
  log "Attempt $i of $MAX_RETRIES to fetch logs from pod '$POD_NAME'..."
  
  if ! kube_log_output=$(kubectl logs --tail=50 --timeout=30s "$POD_NAME" -n "$NAMESPACE" 2>&1); then
    log "Warning: Failed to retrieve logs on attempt $i."
    if [ $i -eq $MAX_RETRIES ]; then
      log "❌ Failure: Failed to retrieve logs after $MAX_RETRIES attempts."
      exit 1 # Assume pod diagnostics were captured in previous workflow step
    fi
  else
    echo "$kube_log_output" > "$LOG_FILE"
    if grep -q "$EXPECTED_LOG" "$LOG_FILE"; then
      log "✅ Success: '$EXPECTED_LOG' found in logs."
      found_log=true
      break
    else
      log "Warning: '$EXPECTED_LOG' not found in logs on attempt $i."
    fi
  fi
  
  log "Waiting $RETRY_INTERVAL seconds before retrying..."
  sleep $RETRY_INTERVAL
done

if [ "$found_log" = false ]; then
  log "❌ Failure: '$EXPECTED_LOG' not found in logs after $MAX_RETRIES attempts."
  exit 1
fi

log "--- Ephemeral Check Completed Successfully ---"
exit 0
