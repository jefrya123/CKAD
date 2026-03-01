# Troubleshooting Labs

12 broken YAML files that you must diagnose and fix. Each has a `broken/` version (apply it, watch it fail) and a `solution/` version.

## How to Use

1. Apply the broken YAML: `kubectl apply -f broken/lab-XX.yaml`
2. Observe the failure (pod won't start, service doesn't work, etc.)
3. Use `kubectl describe`, `kubectl logs`, `kubectl get events` to find the bug
4. Fix it yourself — then compare with `solution/lab-XX.yaml`

## Labs

| # | Bug | Difficulty |
|---|-----|-----------|
| 01 | Wrong image name (typo) | ⭐ |
| 02 | Wrong container port in service | ⭐ |
| 03 | Missing volume mount | ⭐ |
| 04 | Wrong API version for Ingress | ⭐⭐ |
| 05 | Label selector mismatch | ⭐⭐ |
| 06 | Liveness probe wrong port | ⭐⭐ |
| 07 | Secret referenced but doesn't exist | ⭐⭐ |
| 08 | PVC access mode mismatch | ⭐⭐ |
| 09 | CronJob invalid schedule | ⭐ |
| 10 | Deployment selector doesn't match template | ⭐⭐⭐ |
| 11 | NetworkPolicy blocks all traffic (missing egress DNS) | ⭐⭐⭐ |
| 12 | Multiple bugs in one manifest | ⭐⭐⭐ |
