# Scenarios & Practice Labs

Two types of practice here — pick what you need:

---

## 🔧 Troubleshooting Labs (`../troubleshooting/`)

Broken manifests you apply to your cluster, watch fail, diagnose, and fix. **This is the most realistic exam prep.**

| # | Bug | Symptom | Difficulty |
|---|-----|---------|------------|
| [lab-01](../troubleshooting/broken/lab-01.yaml) | Typo in image name | `ImagePullBackOff` | ⭐ |
| [lab-02](../troubleshooting/broken/lab-02.yaml) | Service selector mismatch | No Endpoints | ⭐ |
| [lab-03](../troubleshooting/broken/lab-03.yaml) | Volume not mounted | Can't write to `/data` | ⭐ |
| [lab-04](../troubleshooting/broken/lab-04.yaml) | Liveness probe wrong port | RESTARTS climbing | ⭐⭐ |
| [lab-05](../troubleshooting/broken/lab-05.yaml) | Deployment selector ≠ template labels | `0/2` pods | ⭐⭐ |
| [lab-06](../troubleshooting/broken/lab-06.yaml) | Secret doesn't exist | Pod stuck `Pending` | ⭐⭐ |
| [lab-07](../troubleshooting/broken/lab-07.yaml) | PVC requests more than PV has | PVC stuck `Pending` | ⭐⭐ |
| [lab-08](../troubleshooting/broken/lab-08.yaml) | CronJob 6-field schedule | Validation error | ⭐ |
| [lab-09](../troubleshooting/broken/lab-09.yaml) | ConfigMap key mismatch | Env var empty | ⭐⭐ |
| [lab-10](../troubleshooting/broken/lab-10.yaml) | InitContainer missing volumeMount | `Init:CrashLoopBackOff` | ⭐⭐ |
| [lab-11](../troubleshooting/broken/lab-11.yaml) | NetworkPolicy blocks DNS | Can't resolve hostnames | ⭐⭐⭐ |
| [lab-12](../troubleshooting/broken/lab-12.yaml) | Four bugs in one manifest | Nothing works | ⭐⭐⭐ |

```bash
# Run a single lab
kubectl apply -f ../troubleshooting/broken/lab-01.yaml

# Run all labs at once
bash ../troubleshooting/deploy-labs.sh

# Clean everything up
bash ../troubleshooting/deploy-labs.sh clean
```

See [`../troubleshooting/README.md`](../troubleshooting/README.md) for the full debugging command reference.

---

## 🏋️ Practice Scenarios (this folder)

Full end-to-end tasks with a setup phase, your tasks, verification commands, and a hidden solution. Time yourself.

| # | Scenario | Domain | Time | Difficulty |
|---|----------|--------|------|------------|
| [01](practice-01-rollout-rescue.md) | Rollout Rescue — find & rollback a broken deployment | Deployments | 8 min | ⭐⭐⭐ |
| [02](practice-02-broken-service.md) | The Dead Service — 3 bugs, curl must work at the end | Networking | 6 min | ⭐⭐⭐ |
| [03](practice-03-secret-injection.md) | Secret Injection — env var + volume mount | Config & Security | 6 min | ⭐⭐ |
| [04](practice-04-pod-to-deployment.md) | Pod to Deployment — migrate and expose | App Design | 7 min | ⭐⭐ |
| [05](practice-05-networkpolicy-lockdown.md) | NetworkPolicy Lockdown — 3 policies, test each | Networking | 10 min | ⭐⭐⭐⭐ |
| [06](practice-06-storage-chain.md) | Storage Chain — PV→PVC→writer pod→reader pod | Storage | 10 min | ⭐⭐⭐ |

---

## Original Quick-Fire Scenarios

25 timed exam-style scenarios covering all 5 CKAD domains.

### Domain 1: Application Design & Build
| # | Scenario | Time |
|---|----------|------|
| 01 | [Create Multi-Container Pod](scenario-01-multi-container-pod.md) | 3 min |
| 02 | [Init Container Setup](scenario-02-init-container.md) | 3 min |
| 03 | [Create a Job](scenario-03-job.md) | 2 min |
| 04 | [CronJob with History Limits](scenario-04-cronjob.md) | 3 min |
| 05 | [Pod with PVC](scenario-05-pod-with-pvc.md) | 3 min |

### Domain 2: Application Deployment
| # | Scenario | Time |
|---|----------|------|
| 06 | [Rolling Update](scenario-06-rolling-update.md) | 3 min |
| 07 | [Rollback Deployment](scenario-07-rollback.md) | 2 min |
| 08 | [Helm Install & Upgrade](scenario-08-helm.md) | 4 min |
| 09 | [Scale & Update Deployment](scenario-09-scale-update.md) | 2 min |
| 10 | [Canary Deployment](scenario-10-canary.md) | 5 min |

### Domain 3: Observability & Maintenance
| # | Scenario | Time |
|---|----------|------|
| 11 | [Add Liveness Probe](scenario-11-liveness-probe.md) | 3 min |
| 12 | [Readiness + Liveness Probes](scenario-12-readiness-probe.md) | 4 min |
| 13 | [Debug CrashLoopBackOff](scenario-13-debug-crash.md) | 3 min |
| 14 | [Container Logging](scenario-14-logging.md) | 2 min |
| 15 | [Fix Failing Probe](scenario-15-fix-probe.md) | 3 min |

### Domain 4: Config & Security
| # | Scenario | Time |
|---|----------|------|
| 16 | [ConfigMap + Secret in Pod](scenario-16-configmap-secret.md) | 4 min |
| 17 | [SecurityContext](scenario-17-security-context.md) | 3 min |
| 18 | [ServiceAccount with RBAC](scenario-18-rbac.md) | 5 min |
| 19 | [Resource Limits](scenario-19-resource-limits.md) | 3 min |
| 20 | [ResourceQuota](scenario-20-resource-quota.md) | 4 min |

### Domain 5: Services & Networking
| # | Scenario | Time |
|---|----------|------|
| 21 | [Expose Deployment as Service](scenario-21-service.md) | 2 min |
| 22 | [Create Ingress](scenario-22-ingress.md) | 4 min |
| 23 | [Network Policy Deny All](scenario-23-netpol-deny.md) | 3 min |
| 24 | [Network Policy Allow Specific](scenario-24-netpol-allow.md) | 5 min |
| 25 | [DNS Debugging](scenario-25-dns.md) | 3 min |
