# CKAD Exam Study Plan

## Progress Tracker

| Domain | Weight | Status |
|--------|--------|--------|
| 1. Application Design and Build | 20% | 🔲 Not Started |
| 2. Application Deployment | 20% | 🔲 Not Started |
| 3. Application Observability and Maintenance | 15% | 🔲 Not Started |
| 4. Application Environment, Configuration and Security | 25% | 🔲 Not Started |
| 5. Services and Networking | 20% | 🔲 Not Started |

## CKAD vs CKA

| CKAD (Developer) | CKA (Admin) |
|------------------|-------------|
| Application design & build | Cluster installation & config |
| Pod patterns (sidecars, init) | etcd backup/restore |
| Probes & observability | RBAC deep dive |
| Helm basics | Node troubleshooting |
| 2 hours, 15-20 questions | 2 hours, 15-20 questions |

## Quick Reference

### Essential kubectl Commands

```bash
# Context & Config
kubectl config get-contexts
kubectl config use-context <context>
kubectl config set-context --current --namespace=<ns>

# Create resources imperatively (faster for exam)
kubectl run nginx --image=nginx
kubectl create deployment nginx --image=nginx --replicas=3
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl create configmap myconfig --from-literal=key=value
kubectl create secret generic mysecret --from-literal=password=secret

# Generate YAML templates
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml > deploy.yaml

# Debugging
kubectl describe pod <pod>
kubectl logs <pod> [-c container] [--previous]
kubectl exec -it <pod> -- /bin/sh
kubectl get events --sort-by='.lastTimestamp'

# Quick edits
kubectl edit deployment <name>
kubectl set image deployment/<name> container=image:tag
kubectl scale deployment <name> --replicas=5
kubectl rollout status/history/undo deployment/<name>
```

### Exam Tips
- Use `alias k=kubectl` and enable shell completion
- Use `-o wide` for more info, `-o yaml` to see full spec
- Use `--dry-run=client -o yaml` to generate manifests
- Master vim basics: `i`, `Esc`, `:wq`, `dd`, `yy`, `p`
- Bookmark kubernetes.io/docs - only allowed reference

## Study Schedule

- [ ] Week 1: Domain 1 - Application Design and Build (20%)
- [ ] Week 2: Domain 2 - Application Deployment (20%)
- [ ] Week 3: Domain 3 - Observability and Maintenance (15%)
- [ ] Week 4: Domain 4 - Config and Security (25%)
- [ ] Week 5: Domain 5 - Services and Networking (20%)
- [ ] Week 6: Practice exams & review

## Resources
- [Kubernetes Official Docs](https://kubernetes.io/docs/)
- [CKAD Exam Curriculum](https://github.com/cncf/curriculum)
- [killer.sh Practice Exams](https://killer.sh/)
- [CKAD Exercises](https://github.com/dgkanatsios/CKAD-exercises)
