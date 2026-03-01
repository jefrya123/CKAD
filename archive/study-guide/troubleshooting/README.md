# Troubleshooting Labs

12 broken manifests that mirror the exact question types from the KillerShell CKAD simulator.

**How to use:**
1. Read the comment header in the broken YAML — it tells you the symptom but NOT the fix
2. Apply it: `kubectl apply -f broken/lab-XX.yaml`
3. Reproduce the symptom yourself with the verification commands in the header
4. Debug and fix it on your own
5. Only then diff with the solution: `diff broken/lab-XX.yaml solution/lab-XX.yaml`

---

## Labs

| Lab | KillerShell Q | Topic | Bug Type | Symptom |
|-----|--------------|-------|----------|---------|
| [lab-01](broken/lab-01.yaml) | Q2  | Pods | Wrong container name + bad label | Pod runs but spec is wrong |
| [lab-02](broken/lab-02.yaml) | Q3  | Job | Wrong parallelism + wrong label key | Job runs but pods not labelled correctly |
| [lab-03](broken/lab-03.yaml) | Q5  | ServiceAccount Secret | Wrong secret type | Token field empty, not a real SA token |
| [lab-04](broken/lab-04.yaml) | Q6  | ReadinessProbe | Wrong path + wrong port | Pod stuck at `0/1 READY` |
| [lab-05](broken/lab-05.yaml) | Q7  | Pod Namespace Migration | Pod in wrong namespace | Pod running in neptune, should be pluto |
| [lab-06](broken/lab-06.yaml) | Q8  | Deployment Rollback | Bad image tag | `0/2` pods, `ImagePullBackOff` |
| [lab-07](broken/lab-07.yaml) | Q9  | Pod→Deployment | Selector mismatch + wrong replicas | Deployment shows wrong READY count |
| [lab-08](broken/lab-08.yaml) | Q10 | Service + Logs | Selector + targetPort wrong | Endpoints empty, curl fails |
| [lab-09](broken/lab-09.yaml) | Q12 | PV/PVC Storage | PVC access mode + size mismatch | PVC stuck `Pending` |
| [lab-10](broken/lab-10.yaml) | Q14 | Secret Env + Volume | Key name mismatches + wrong secret name | Env vars empty, volume missing |
| [lab-11](broken/lab-11.yaml) | Q16 | Logging Sidecar | Sidecar uses wrong volume name | `kubectl logs -c log-reader` shows nothing |
| [lab-12](broken/lab-12.yaml) | Q17+Q18+Q20 | Init + Service + NetworkPolicy | Three bugs across three resources | Nothing works |

---

## Quick Start

```bash
# Apply a single lab
kubectl apply -f broken/lab-01.yaml

# Apply all labs at once
bash deploy-labs.sh

# Clean up everything
bash deploy-labs.sh clean
```

## Debugging Reference

```bash
# Pod not starting?
kubectl get pods -A
kubectl describe pod <name> -n <ns>     # check Events at the bottom
kubectl logs <name> -n <ns>
kubectl logs <name> -n <ns> --previous  # if already crashed

# Service not routing?
kubectl get endpoints <svc> -n <ns>     # empty = selector mismatch
kubectl get pods -n <ns> --show-labels  # compare to service selector

# PVC not binding?
kubectl get pvc -n <ns>                 # check STATUS
kubectl describe pvc <name> -n <ns>     # "no matching volumes" or similar
kubectl get pv                          # check capacity and accessModes

# NetworkPolicy blocking unexpected traffic?
kubectl describe networkpolicy <name> -n <ns>
kubectl exec <pod> -- wget -qO- --timeout=2 <ip>   # test connectivity
```
