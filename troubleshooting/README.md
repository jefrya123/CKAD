# Troubleshooting Labs

12 broken manifests. Apply them, watch them fail, diagnose the problem, fix it yourself. Only check the solution when you're done or truly stuck.

## How to Use

```bash
# 1. Apply the broken manifest
kubectl apply -f broken/lab-XX.yaml

# 2. Watch what happens
kubectl get pods -w
kubectl describe pod <name>
kubectl logs <name>
kubectl get events --sort-by='.lastTimestamp'

# 3. Fix it — edit the broken file or write your own corrected version

# 4. Compare with the solution
diff broken/lab-XX.yaml solution/lab-XX.yaml
# or just read solution/lab-XX.yaml
```

## Clean Up Between Labs

```bash
kubectl delete -f broken/lab-XX.yaml --force --grace-period=0
# or wipe everything:
kubectl delete pods,deployments,services,cronjobs,pvc,pv,networkpolicies,configmaps,secrets -l lab --all
```

---

## Labs

| # | Bug Type | Symptom You'll See | Difficulty |
|---|----------|--------------------|------------|
| [01](broken/lab-01.yaml) | Typo in image name | `ImagePullBackOff` | ⭐ |
| [02](broken/lab-02.yaml) | Service selector mismatch | No Endpoints, curl times out | ⭐ |
| [03](broken/lab-03.yaml) | Volume defined but not mounted | Container can't write to `/data` | ⭐ |
| [04](broken/lab-04.yaml) | Liveness probe on wrong port | RESTARTS count climbs every ~10s | ⭐⭐ |
| [05](broken/lab-05.yaml) | Deployment selector ≠ template labels | `0/2` pods, selector error | ⭐⭐ |
| [06](broken/lab-06.yaml) | Secret referenced but missing | Pod stuck in `Pending` | ⭐⭐ |
| [07](broken/lab-07.yaml) | PVC requests more than PV offers | PVC stuck in `Pending`, pod won't schedule | ⭐⭐ |
| [08](broken/lab-08.yaml) | CronJob has 6-field cron schedule | Validation error on apply | ⭐ |
| [09](broken/lab-09.yaml) | ConfigMap key name mismatch | Pod runs but env var is empty | ⭐⭐ |
| [10](broken/lab-10.yaml) | InitContainer missing volumeMount | `Init:CrashLoopBackOff` | ⭐⭐ |
| [11](broken/lab-11.yaml) | NetworkPolicy blocks DNS egress | Pod can't resolve hostnames | ⭐⭐⭐ |
| [12](broken/lab-12.yaml) | Four bugs in one manifest | Nothing works at all | ⭐⭐⭐ |

---

## Debugging Command Reference

```bash
# Where to start every time
kubectl get pods -o wide
kubectl describe pod <name>          # look at Events section at the bottom
kubectl logs <name>
kubectl logs <name> --previous       # if container already crashed

# Service not working?
kubectl get endpoints <svc-name>     # empty = selector mismatch
kubectl get pods --show-labels       # compare to svc selector

# PVC not binding?
kubectl get pvc                      # check STATUS column
kubectl describe pvc <name>          # look for "no matching volumes" etc
kubectl get pv                       # check CAPACITY and ACCESS MODES

# Probe issues?
kubectl describe pod <name>          # look for "Liveness probe failed" in Events
kubectl get pod <name> -o wide       # check RESTARTS column

# NetworkPolicy blocking things?
kubectl get networkpolicy -A
kubectl describe networkpolicy <name>
kubectl exec <pod> -- wget -qO- http://8.8.8.8   # bypass DNS to test connectivity
kubectl exec <pod> -- nslookup kubernetes         # test DNS specifically
```
