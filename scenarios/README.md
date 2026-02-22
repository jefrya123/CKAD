# Practice Scenarios

All 22 practice scenarios map 1-to-1 to the KillerShell CKAD simulator questions.

---

## Quick Start

```bash
# Deploy ALL scenario setups at once (skips Helm/Q04 — needs helm installed separately)
bash scenarios/setup-all.sh

# Deploy a single scenario's setup
bash scenarios/setup-all.sh q02

# Tear everything down and start fresh
bash scenarios/setup-all.sh clean
```

---

## How to Use Each Scenario

1. Run `bash setup-all.sh qXX` to create the starting cluster state
2. Open the scenario file and read **only the "Your Task" section** — don't peek at hints or solution
3. Set a timer and work through it live in your cluster
4. Run the **Verification** commands to check your work
5. Only expand the solution if stuck or to compare approaches

---

## All 22 Scenarios

| # | File | KillerShell Topic | Time |
|---|------|-------------------|------|
| Q01 | [practice-q01-namespaces.md](practice-q01-namespaces.md) | Namespaces — investigate running pods across namespaces | 3 min |
| Q02 | [practice-q02-pods.md](practice-q02-pods.md) | Pods — debug ImagePullBackOff, fix container name & label | 4 min |
| Q03 | [practice-q03-job.md](practice-q03-job.md) | Job — observe broken job, replace with parallelism: 2 | 5 min |
| Q04 | [practice-q04-helm.md](practice-q04-helm.md) | Helm — uninstall, upgrade, install | 6 min |
| Q05 | [practice-q05-serviceaccount-secret.md](practice-q05-serviceaccount-secret.md) | ServiceAccount — find correct secret, decode JWT token | 5 min |
| Q06 | [practice-q06-readinessprobe.md](practice-q06-readinessprobe.md) | ReadinessProbe — add httpGet probe to existing pod | 5 min |
| Q07 | [practice-q07-pod-namespace-migration.md](practice-q07-pod-namespace-migration.md) | Pod migration between namespaces | 6 min |
| Q08 | [practice-q08-deployment-rollback.md](practice-q08-deployment-rollback.md) | Deployment rollout debug & rollback to specific revision | 7 min |
| Q09 | [practice-q09-pod-to-deployment.md](practice-q09-pod-to-deployment.md) | Pod → Deployment conversion + expose as ClusterIP | 6 min |
| Q10 | [practice-q10-service-logs.md](practice-q10-service-logs.md) | ClusterIP service + curl test + save logs | 6 min |
| Q11 | [practice-q11-containers.md](practice-q11-containers.md) | Build container image, run, save as tar | 7 min |
| Q12 | [practice-q12-storage-pv-pvc.md](practice-q12-storage-pv-pvc.md) | PV + PVC + Pod volume mount | 8 min |
| Q13 | [practice-q13-storageclass.md](practice-q13-storageclass.md) | StorageClass + PVC + WaitForFirstConsumer | 6 min |
| Q14 | [practice-q14-secret-volume-env.md](practice-q14-secret-volume-env.md) | Secret as env var + volume mount | 7 min |
| Q15 | [practice-q15-configmap.md](practice-q15-configmap.md) | ConfigMap volume (subPath) + env var | 7 min |
| Q16 | [practice-q16-logging-sidecar.md](practice-q16-logging-sidecar.md) | Add logging sidecar to existing deployment | 7 min |
| Q17 | [practice-q17-initcontainer.md](practice-q17-initcontainer.md) | InitContainer pre-populating a shared volume | 6 min |
| Q18 | [practice-q18-service-misconfiguration.md](practice-q18-service-misconfiguration.md) | Troubleshoot broken service — find & fix 2 bugs | 6 min |
| Q19 | [practice-q19-clusterip-to-nodeport.md](practice-q19-clusterip-to-nodeport.md) | Convert ClusterIP → NodePort, verify, save nodePort | 4 min |
| Q20 | [practice-q20-networkpolicy.md](practice-q20-networkpolicy.md) | NetworkPolicy — allow from mars ns, deny everything else | 8 min |
| Q21 | [practice-q21-requests-limits-sa.md](practice-q21-requests-limits-sa.md) | Create 3 pods with requests/limits + ServiceAccount | 8 min |
| Q22 | [practice-q22-labels-annotations.md](practice-q22-labels-annotations.md) | Labels + annotations — filter, add, remove | 6 min |

**Total time:** ~130 minutes (just over 2 hours — mirrors real exam pacing)

---

## Troubleshooting Labs

For broken manifests that map to KillerShell questions see [`../troubleshooting/`](../troubleshooting/README.md).

These are harder — you apply a broken YAML, watch it fail, and diagnose and fix it without being told what's wrong upfront.

```bash
# Deploy all broken labs
bash troubleshooting/deploy-labs.sh

# Deploy a single lab
bash troubleshooting/deploy-labs.sh 1

# Tear down all labs
bash troubleshooting/deploy-labs.sh clean
```
