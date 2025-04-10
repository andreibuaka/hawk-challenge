#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
# Exit if unset variables are used.
# Prevent errors in a pipeline from being masked.
set -euo pipefail

# Basic smoke test for the ephemeral deployment

LOG_FILE="ephemeral-logs.txt"
MAX_WAIT_SECONDS=90
RETRY_INTERVAL=5
MAX_RETRIES=3

echo "--- Starting Ephemeral Check ---"
echo "$(date): Beginning verification of ephemeral deployment"

# Function to print timestamps with messages
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

# Function to clean up resources on exit
cleanup() {
  log "Cleaning up resources"
  if [ -f "$LOG_FILE" ]; then
    log "Preserving logs for debugging"
    cp "$LOG_FILE" "ephemeral-logs-$(date +%s).txt" || true
  fi
}

# Set up trap for cleanup on script exit
trap cleanup EXIT

# 1. Wait for the pod to be running with retries
log "Waiting up to $MAX_WAIT_SECONDS seconds for pod to be running..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=ephemeral-hello --timeout=${MAX_WAIT_SECONDS}s || {
  log "❌ Failure: Pod did not become ready within timeout period"
  kubectl get pods -l app.kubernetes.io/instance=ephemeral-hello -o wide
  kubectl describe pods -l app.kubernetes.io/instance=ephemeral-hello
  exit 1
}

# 2. Get the pod name
POD_NAME=$(kubectl get pods -l app.kubernetes.io/instance=ephemeral-hello -o jsonpath="{.items[0].metadata.name}")
if [ -z "$POD_NAME" ]; then
  log "❌ Failure: Could not find running pod for ephemeral-hello instance."
  kubectl get pods --all-namespaces
  exit 1
fi
log "Pod found: $POD_NAME"

# 3. Check logs for expected output with retries
log "Checking logs for 'Hello World' output..."

for ((i=1; i<=MAX_RETRIES; i++)); do
  log "Attempt $i of $MAX_RETRIES to fetch logs"
  
  # Add timeout to log fetching
  if ! kube_log_output=$(kubectl logs --timeout=30s "$POD_NAME" 2>&1); then
    log "Warning: Failed to retrieve logs from pod $POD_NAME on attempt $i."
    if [ $i -eq $MAX_RETRIES ]; then
      log "❌ Failure: Failed to retrieve logs after $MAX_RETRIES attempts."
      kubectl describe pod "$POD_NAME"
      exit 1
    fi
    log "Waiting $RETRY_INTERVAL seconds before retrying..."
    sleep $RETRY_INTERVAL
    continue
  fi

  echo "$kube_log_output" > "$LOG_FILE"

  if grep -q "Hello World" "$LOG_FILE"; then
    log "✅ Success: 'Hello World' found in logs."
    break
  else
    log "Warning: 'Hello World' not found in logs on attempt $i."
    if [ $i -eq $MAX_RETRIES ]; then
      log "❌ Failure: 'Hello World' not found in logs after $MAX_RETRIES attempts."
      log "--- Pod Logs ($POD_NAME) ---"
      cat "$LOG_FILE"
      log "---------------------------"
      kubectl describe pod "$POD_NAME"
      exit 1
    fi
    log "Waiting $RETRY_INTERVAL seconds before retrying..."
    sleep $RETRY_INTERVAL
  fi
done

# 4. Additional verification - check pod status one more time
pod_status=$(kubectl get pod "$POD_NAME" -o jsonpath="{.status.phase}")
if [ "$pod_status" != "Running" ]; then
  log "❌ Failure: Pod is no longer in Running state. Current state: $pod_status"
  kubectl describe pod "$POD_NAME"
  exit 1
fi

log "--- Ephemeral Check Completed Successfully ---"
log "Total verification time: $SECONDS seconds"
exit 0
