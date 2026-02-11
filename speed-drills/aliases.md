# Aliases & Shortcuts

## Exam Setup (Do First!)

```bash
# Essential — saves hundreds of keystrokes
alias k=kubectl
complete -o default -F __start_kubectl k

# YAML generation shortcut
export do="--dry-run=client -o yaml"

# Fast delete
export now="--force --grace-period=0"

# Usage:
# k run nginx --image=nginx $do > pod.yaml
# k delete pod nginx $now
```

## Recommended Aliases

```bash
# Get commands
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods -A'
alias kgd='kubectl get deploy'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kgi='kubectl get ingress'
alias kgcm='kubectl get configmap'
alias kgsec='kubectl get secret'
alias kgns='kubectl get ns'
alias kgpv='kubectl get pv'
alias kgpvc='kubectl get pvc'

# Describe
alias kdp='kubectl describe pod'
alias kdd='kubectl describe deploy'
alias kds='kubectl describe svc'

# Apply/Delete
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'

# Namespace switch
alias kns='kubectl config set-context --current --namespace'

# Logs
alias kl='kubectl logs'
alias klf='kubectl logs -f'

# Wide output
alias kgpw='kubectl get pods -o wide'
```

## Quick Context Switch

```bash
# List contexts
k config get-contexts

# Switch context
k config use-context <name>

# Set namespace
k config set-context --current --namespace=dev
```

## Bash One-Liners for Exam

```bash
# Get all images in cluster
k get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort -u

# Get pods not in Running state
k get pods -A --field-selector=status.phase!=Running

# Get all resources in a namespace
k api-resources --verbs=list -o name | xargs -n 1 kubectl get -n <ns> --show-kind --ignore-not-found

# Watch pod status changes
k get pods -w

# Quick port-forward
k port-forward svc/my-svc 8080:80
```
