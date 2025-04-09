#!/bin/bash

set -euo pipefail

# Basic smoke test for the ephemeral deployment

LOG_FILE="ephemeral-logs.txt"
MAX_WAIT_SECONDS=60

echo "--- Starting Ephemeral Check ---"

# 1. Wait for the pod to be running
echo "Waiting up to $MAX_WAIT_SECONDS seconds for pod to be running..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=ephemeral-hello --timeout=${MAX_WAIT_SECONDS}s

# 2. Get the pod name
POD_NAME=$(kubectl get pods -l app.kubernetes.io/instance=ephemeral-hello -o jsonpath="{.items[0].metadata.name}")
echo "Pod found: $POD_NAME"

# 3. Check logs for expected output
echo "Checking logs for 'Hello World' output..."
kube_log_output=$(kubectl logs "$POD_NAME")
echo "$kube_log_output" > "$LOG_FILE"

if grep -q "Hello World" "$LOG_FILE"; then
  echo "✅ Success: 'Hello World' found in logs."
else
  echo "❌ Failure: 'Hello World' not found in logs."
  echo "--- Pod Logs ($POD_NAME) ---"
  cat "$LOG_FILE"
  echo "---------------------------"
  exit 1
fi

echo "--- Ephemeral Check Completed Successfully ---"
exit 0
