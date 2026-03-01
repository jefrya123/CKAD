# CKAD Exam Workflow Cheatsheet

A practical reference for moving fast and accurately during the real CKAD exam.

---

## First 2 Minutes: Setup

Run these immediately before touching any question:

```bash
# Must-have alias
alias k=kubectl
export do="--dry-run=client -oyaml"
export now="--force --grace-period 0"

# Optional but helpful
alias kg="kubectl get"
alias kd="kubectl describe"
alias kdel="kubectl delete"

# Set vim preferences (paste into ~/.vimrc or run in vim command mode)
# :set expandtab tabstop=2 shiftwidth=2
```

---

## Navigating Questions

| Action | Command |
|--------|---------|
| Check current context | `k config current-context` |
| Switch context | `k config use-context <name>` |
| Set default namespace | `k config set-context --current --namespace=<ns>` |
| Check your namespace | `k config view --minify \| grep namespace` |

> Always switch context AND namespace at the start of each question.

---

## YAML Generation Shortcuts

Generate YAML fast using imperative commands, then edit:

```bash
# Pod
k run <name> --image=<img> $do > pod.yaml

# Deployment
k create deploy <name> --image=<img> --replicas=3 $do > deploy.yaml

# Service
k expose deploy <name> --port=80 --target-port=8080 $do > svc.yaml

# Job
k create job <name> --image=<img> $do > job.yaml

# CronJob
k create cronjob <name> --image=<img> --schedule="*/5 * * * *" $do > cj.yaml

# ConfigMap
k create cm <name> --from-literal=key=val $do > cm.yaml

# Secret
k create secret generic <name> --from-literal=key=val $do > sec.yaml

# ServiceAccount
k create sa <name> $do > sa.yaml
```

---

## Edit vs Replace vs Delete+Apply

| Situation | Best command |
|-----------|-------------|
| Deployment, DaemonSet, StatefulSet | `k edit deploy <name>` |
| Pod (immutable fields) | `k replace --force -f pod.yaml` |
| Any resource with a YAML file | `k apply -f file.yaml` |
| Fast delete | `k delete pod <name> $now` |

---

## Debugging Workflow

When something isn't working, follow this order:

```bash
# 1. Check pod status
k get pods -n <ns> -owide

# 2. Describe for events and conditions
k describe pod <name> -n <ns>

# 3. Check logs
k logs <name> -n <ns>
k logs <name> -n <ns> --previous        # for crashed containers
k logs <name> -n <ns> -c <container>    # multi-container pods

# 4. Exec into the pod
k exec -it <name> -n <ns> -- /bin/sh

# 5. Check events cluster-wide
k get events -n <ns> --sort-by='.lastTimestamp'
```

---

## Resource-Specific Quick Commands

### Deployments & Rollouts
```bash
k rollout status deploy/<name>
k rollout history deploy/<name>
k rollout undo deploy/<name>
k rollout undo deploy/<name> --to-revision=2
k rollout pause deploy/<name>
k rollout resume deploy/<name>
k scale deploy <name> --replicas=5
```

### Pods
```bash
k run tmp --image=busybox --restart=Never -it --rm -- sh   # throwaway debug pod
k run tmp --image=curlimages/curl --restart=Never -it --rm -- curl <url>
k get pod <name> -oyaml                                    # dump full spec
k top pod -n <ns>                                          # resource usage
```

### Namespaces
```bash
k get all -n <ns>
k get pods --all-namespaces
k get pods -A -owide
```

### Services & Networking
```bash
k get svc -n <ns>
k get endpoints -n <ns>
# DNS pattern: <svc>.<ns>.svc.cluster.local
```

### Storage
```bash
k get pv                      # cluster-scoped
k get pvc -n <ns>             # namespaced
k get sc                      # storage classes
```

### Secrets & ConfigMaps
```bash
k get secret <name> -ojsonpath='{.data.<key>}' | base64 -d
k get cm <name> -ojsonpath='{.data.<key>}'
```

---

## Time Management Strategy

| Time Spent | Action |
|------------|--------|
| < 3 minutes | Attempt question fully |
| 3–5 minutes | If stuck, skip and mark for return |
| > 5 minutes | Flag and move on immediately |

- The exam is 2 hours (~17 questions from killer.sh = ~7 min/question)
- Easier questions are worth the same as hard ones — don't over-invest in one
- Always verify your work before moving on (takes 30 seconds, saves you from 0 points)

---

## Verification Checklist

After completing each question, quickly confirm:

- [ ] `k get <resource>` — exists in the correct namespace
- [ ] Status is `Running` / `Bound` / `Complete` as expected
- [ ] Container name, label, or annotation matches exactly what was asked
- [ ] Output file (if required) exists at the specified path: `cat /path/to/file`
- [ ] Service endpoints are populated: `k get endpoints <svc>`

---

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| Wrong namespace | Always set namespace at start of each question |
| Container name ≠ pod name | Check with `k describe pod` |
| PVC stuck `Pending` | Check PV accessModes and storage size match |
| Pod won't restart after edit | Use `k replace --force -f file.yaml` for pods |
| `exec` exit code errors in Job | Set `restartPolicy: Never` in job pod template |
| Secret/CM not updating in pod | Env vars require pod restart; volume mounts update automatically |
| `k apply` rejected due to immutable field | Use `k replace --force -f` or delete and recreate |
