#!/bin/bash
# deploy-labs.sh — Apply all broken troubleshooting labs at once
# Usage: bash deploy-labs.sh [lab-number]
#   bash deploy-labs.sh       -> applies ALL labs
#   bash deploy-labs.sh 04    -> applies only lab-04

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BROKEN_DIR="$SCRIPT_DIR/broken"

apply_lab() {
  local lab=$1
  echo ""
  echo "========================================"
  echo " Applying LAB $lab"
  echo "========================================"
  kubectl apply -f "$BROKEN_DIR/lab-${lab}.yaml"
}

cleanup_lab() {
  local lab=$1
  echo "Cleaning up lab $lab..."
  kubectl delete -f "$BROKEN_DIR/lab-${lab}.yaml" --force --grace-period=0 2>/dev/null || true
}

if [[ -n "$1" ]]; then
  apply_lab "$1"
else
  echo "Applying all broken labs..."
  for f in "$BROKEN_DIR"/lab-*.yaml; do
    num=$(basename "$f" .yaml | sed 's/lab-//')
    apply_lab "$num"
  done
  echo ""
  echo "All labs applied. Use 'kubectl get pods -A' to see what's broken."
  echo "To clean up: bash deploy-labs.sh clean"
fi

if [[ "$1" == "clean" ]]; then
  echo "Cleaning up all labs..."
  for f in "$BROKEN_DIR"/lab-*.yaml; do
    kubectl delete -f "$f" --force --grace-period=0 2>/dev/null || true
  done
  kubectl delete namespace neptune pluto moon saturn storage-lab team-a team-b 2>/dev/null || true
  echo "Done."
fi
