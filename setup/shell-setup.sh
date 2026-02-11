#!/bin/bash
# Source this file: source shell-setup.sh

# Essential aliases
alias k=kubectl
complete -o default -F __start_kubectl k 2>/dev/null

# YAML generation
export do="--dry-run=client -o yaml"
export now="--force --grace-period=0"

# Common shortcuts
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods -A'
alias kgd='kubectl get deploy'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kdp='kubectl describe pod'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'
alias kns='kubectl config set-context --current --namespace'
alias kl='kubectl logs'

# Vim config for YAML
cat << 'EOF' >> ~/.vimrc 2>/dev/null
set tabstop=2
set shiftwidth=2
set expandtab
set autoindent
set number
EOF

echo "Shell configured! Try: k get nodes"
