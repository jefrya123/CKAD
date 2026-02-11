# CKAD Exam Study Guide — The Ultimate Hands-On Reference

> **Certified Kubernetes Application Developer** — 2 hours, 15–20 performance-based tasks.
> Pass mark: 66%. Open-book: kubernetes.io/docs only.

## Progress Tracker

| # | Domain | Weight | Status |
|---|--------|--------|--------|
| 1 | [Application Design and Build](domains/01-design-build/) | 20% | 🔲 |
| 2 | [Application Deployment](domains/02-deployment/) | 20% | 🔲 |
| 3 | [Application Observability & Maintenance](domains/03-observability/) | 15% | 🔲 |
| 4 | [App Environment, Configuration & Security](domains/04-config-security/) | 25% | 🔲 |
| 5 | [Services and Networking](domains/05-networking/) | 20% | 🔲 |

## Bonus Material

| Section | Description |
|---------|-------------|
| [Quick-Fire Scenarios](scenarios/) | 25 timed exam-style tasks (2–5 min each) |
| [Troubleshooting Labs](troubleshooting/) | 12 broken YAMLs to diagnose & fix |
| [Quizzes](quizzes/) | Per-domain quizzes + comprehensive mock |
| [Speed Drills](speed-drills/) | kubectl one-liners, aliases, vim tips |
| [Cheatsheet](cheatsheet.md) | Single-page ultimate reference |
| [Practice Setup](setup/) | kind cluster + auto-deploy script |

---

## 6-Week Study Plan

### Week 1 — Application Design & Build (20%)
- [ ] Read [Domain 1 README](domains/01-design-build/README.md) and [tutorial](domains/01-design-build/tutorial.md)
- [ ] Complete all Domain 1 exercises
- [ ] Do scenarios 01–05
- [ ] Troubleshooting labs 01–03
- [ ] Quiz: [Domain 1 Quiz](quizzes/01-design-build.md)

### Week 2 — Application Deployment (20%)
- [ ] Read [Domain 2 README](domains/02-deployment/README.md)
- [ ] Complete all Domain 2 exercises
- [ ] Do scenarios 06–10
- [ ] Troubleshooting labs 04–05
- [ ] Quiz: [Domain 2 Quiz](quizzes/02-deployment.md)

### Week 3 — Observability & Maintenance (15%)
- [ ] Read [Domain 3 README](domains/03-observability/README.md)
- [ ] Complete all Domain 3 exercises
- [ ] Do scenarios 11–15
- [ ] Troubleshooting labs 06–08
- [ ] Quiz: [Domain 3 Quiz](quizzes/03-observability.md)

### Week 4 — Configuration & Security (25%)
- [ ] Read [Domain 4 README](domains/04-config-security/README.md)
- [ ] Complete all Domain 4 exercises
- [ ] Do scenarios 16–20
- [ ] Troubleshooting labs 09–10
- [ ] Quiz: [Domain 4 Quiz](quizzes/04-config-security.md)

### Week 5 — Services & Networking (20%)
- [ ] Read [Domain 5 README](domains/05-networking/README.md)
- [ ] Complete all Domain 5 exercises
- [ ] Do scenarios 21–25
- [ ] Troubleshooting labs 11–12
- [ ] Quiz: [Domain 5 Quiz](quizzes/05-networking.md)

### Week 6 — Review & Mock Exams
- [ ] [Speed Drills](speed-drills/) — all sections
- [ ] [Comprehensive Mock Quiz](quizzes/mock-exam.md)
- [ ] killer.sh practice exam #1
- [ ] killer.sh practice exam #2
- [ ] Review weak areas, redo failed scenarios
- [ ] Print [cheatsheet](cheatsheet.md) for quick review

---

## CKAD vs CKA

| CKAD (Developer) | CKA (Admin) |
|---|---|
| Application design & build | Cluster install & config |
| Pod patterns (sidecars, init) | etcd backup/restore |
| Probes & observability | Node troubleshooting |
| Helm basics | Cluster upgrades |
| Network policies (app focus) | RBAC deep dive |
| 2 hours, 15–20 questions | 2 hours, 15–20 questions |

## Essential Exam Setup (Do First!)

```bash
alias k=kubectl
complete -o default -F __start_kubectl k
export do="--dry-run=client -o yaml"

# Then: k run nginx --image=nginx $do > pod.yaml
```

## Resources

- [Kubernetes Official Docs](https://kubernetes.io/docs/) — **only allowed reference in exam**
- [CKAD Exam Curriculum](https://github.com/cncf/curriculum)
- [killer.sh Practice Exams](https://killer.sh/) — included with exam purchase
- [CKAD Exercises by dgkanatsios](https://github.com/dgkanatsios/CKAD-exercises)
- [kubectl Cheatsheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
