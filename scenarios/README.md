# Practice Scenarios

All 22 practice scenarios map 1-to-1 to the KillerShell CKAD simulator questions.

**How to use each scenario:**
1. Run the **Setup** commands to create the starting state
2. Read only the **Your Task** section — don't peek at hints or solution yet
3. Set a timer and work through it in your cluster
4. Verify with the **Verification** commands
5. Only open the solution if you're stuck or want to compare

---

## All 22 Scenarios

| # | File | KillerShell Topic | Time |
|---|------|-------------------|------|
| Q01 | [practice-q01-namespaces.md](practice-q01-namespaces.md) | Namespaces — list & save | 3 min |
| Q02 | [practice-q02-pods.md](practice-q02-pods.md) | Pods — specific container name & label | 4 min |
| Q03 | [practice-q03-job.md](practice-q03-job.md) | Job — parallelism, completions, pod labels | 5 min |
| Q04 | [practice-q04-helm.md](practice-q04-helm.md) | Helm — uninstall, upgrade, install | 6 min |
| Q05 | [practice-q05-serviceaccount-secret.md](practice-q05-serviceaccount-secret.md) | ServiceAccount + Secret token decode | 5 min |
| Q06 | [practice-q06-readinessprobe.md](practice-q06-readinessprobe.md) | ReadinessProbe — add to existing pod | 5 min |
| Q07 | [practice-q07-pod-namespace-migration.md](practice-q07-pod-namespace-migration.md) | Pod migration between namespaces | 6 min |
| Q08 | [practice-q08-deployment-rollback.md](practice-q08-deployment-rollback.md) | Deployment rollout debug & rollback | 7 min |
| Q09 | [practice-q09-pod-to-deployment.md](practice-q09-pod-to-deployment.md) | Pod → Deployment conversion + expose | 6 min |
| Q10 | [practice-q10-service-logs.md](practice-q10-service-logs.md) | ClusterIP service + curl test + logs | 6 min |
| Q11 | [practice-q11-containers.md](practice-q11-containers.md) | Build & run container image | 7 min |
| Q12 | [practice-q12-storage-pv-pvc.md](practice-q12-storage-pv-pvc.md) | PV + PVC + Pod volume mount | 8 min |
| Q13 | [practice-q13-storageclass.md](practice-q13-storageclass.md) | StorageClass + PVC | 6 min |
| Q14 | [practice-q14-secret-volume-env.md](practice-q14-secret-volume-env.md) | Secret as env var + volume | 7 min |
| Q15 | [practice-q15-configmap.md](practice-q15-configmap.md) | ConfigMap volume + env var | 7 min |
| Q16 | [practice-q16-logging-sidecar.md](practice-q16-logging-sidecar.md) | Logging sidecar pattern | 7 min |
| Q17 | [practice-q17-initcontainer.md](practice-q17-initcontainer.md) | InitContainer pre-populating a volume | 6 min |
| Q18 | [practice-q18-service-misconfiguration.md](practice-q18-service-misconfiguration.md) | Troubleshoot broken service (2 bugs) | 6 min |
| Q19 | [practice-q19-clusterip-to-nodeport.md](practice-q19-clusterip-to-nodeport.md) | ClusterIP → NodePort conversion | 4 min |
| Q20 | [practice-q20-networkpolicy.md](practice-q20-networkpolicy.md) | NetworkPolicy — namespace ingress control | 8 min |
| Q21 | [practice-q21-requests-limits-sa.md](practice-q21-requests-limits-sa.md) | Requests/Limits + ServiceAccount on 3 pods | 8 min |
| Q22 | [practice-q22-labels-annotations.md](practice-q22-labels-annotations.md) | Labels + annotations — find, add, remove | 6 min |

---

## Troubleshooting Labs

For broken manifests that map to KillerShell questions see [`../troubleshooting/`](../troubleshooting/README.md).

These are harder — you apply a broken YAML, watch it fail, and have to diagnose and fix it without being told what's wrong.
