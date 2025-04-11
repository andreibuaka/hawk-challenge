#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
# Exit if unset variables are used.
# Prevent errors in a pipeline from being masked.
set -euo pipefail

# Basic smoke test for the ephemeral deployment

LOG_FILE="ephemeral-logs.txt"
MAX_WAIT_SECONDS=120 # Increased wait slightly
RETRY_INTERVAL=10
MAX_RETRIES=5
DEPLOYMENT_NAME="ephemeral-hello-hello-world" # Helm release-chart name
NAMESPACE="default"

echo "--- Starting Ephemeral Check ---"

log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

cleanup() {
  log "Cleanup trap called"
}

trap cleanup EXIT

# 1. Check if deployment exists
log "Checking if deployment '$DEPLOYMENT_NAME' exists..."
if ! kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" > /dev/null; then
  log "❌ Failure: Deployment '$DEPLOYMENT_NAME' not found."
  kubectl get deployments -n "$NAMESPACE"
  exit 1
fi
log "Deployment found."

# 2. Wait for at least one pod to be running (use kubectl wait)
log "Waiting up to $MAX_WAIT_SECONDS seconds for at least one pod to be running..."
if ! kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=ephemeral-hello -n "$NAMESPACE" --timeout=${MAX_WAIT_SECONDS}s; then
  log "❌ Failure: Pod did not become ready within timeout period."
  log "--- Describing Deployment '$DEPLOYMENT_NAME' --- "
  kubectl describe deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE"
  log "--- Listing Pods for '$DEPLOYMENT_NAME' --- "
  kubectl get pods -l app.kubernetes.io/instance=ephemeral-hello -n "$NAMESPACE" -o wide
  log "--- Describing Pods for '$DEPLOYMENT_NAME' --- "
  kubectl describe pods -l app.kubernetes.io/instance=ephemeral-hello -n "$NAMESPACE"
  exit 1
fi
log "At least one pod is Ready."

# 3. Get the pod name (use the label from Helm release)
POD_NAME=$(kubectl get pods -l app.kubernetes.io/instance=ephemeral-hello -n "$NAMESPACE" -o jsonpath="{.items[0].metadata.name}")
if [ -z "$POD_NAME" ]; then
  log "❌ Failure: Could not find running pod name for instance ephemeral-hello."
  kubectl get pods -n "$NAMESPACE"
  exit 1
fi
log "Using pod: $POD_NAME"

# 4. Check logs for expected output with retries
log "Checking logs of pod '$POD_NAME' for 'Hello World' output..."

found_log=false
for ((i=1; i<=MAX_RETRIES; i++)); do
  log "Attempt $i of $MAX_RETRIES to fetch logs..."
  
  if ! kube_log_output=$(kubectl logs --tail=50 --timeout=30s "$POD_NAME" -n "$NAMESPACE" 2>&1); then
    log "Warning: Failed to retrieve logs from pod '$POD_NAME' on attempt $i."
    if [ $i -eq $MAX_RETRIES ]; then
      log "❌ Failure: Failed to retrieve logs after $MAX_RETRIES attempts."
      log "--- Final Pod Description ($POD_NAME) --- "
      kubectl describe pod "$POD_NAME" -n "$NAMESPACE"
      exit 1
    fi
    log "Waiting $RETRY_INTERVAL seconds before retrying..."
    sleep $RETRY_INTERVAL
    continue
  fi

  echo "$kube_log_output" > "$LOG_FILE"

  if grep -q "Hello World" "$LOG_FILE"; then
    log "✅ Success: 'Hello World' found in logs."
    found_log=true
    break
  else
    log "Warning: 'Hello World' not found in logs on attempt $i."
    if [ $i -eq $MAX_RETRIES ]; then
      log "❌ Failure: 'Hello World' not found in logs after $MAX_RETRIES attempts."
    else
      log "Waiting $RETRY_INTERVAL seconds before retrying..."
      sleep $RETRY_INTERVAL
    fi
  fi
done

if [ "$found_log" = false ]; then
  log "--- Final Pod Logs ($POD_NAME) --- "
  cat "$LOG_FILE"
  log "----------------------------------"
  log "--- Final Pod Description ($POD_NAME) --- "
  kubectl describe pod "$POD_NAME" -n "$NAMESPACE"
  exit 1
fi

log "--- Ephemeral Check Completed Successfully ---"
exit 0
