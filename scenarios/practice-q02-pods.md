# Practice Q02 — Pods

**Mirrors KillerShell CKAD Question 2**
**Time target:** 4 minutes

---

## Setup

```bash
kubectl create namespace neptune
```

---

## Your Task

Create a pod in namespace `neptune` with:
- Pod name: `neptune-pod`
- Container name: `neptune-container` ← **this is different from the pod name, don't miss it**
- Image: `nginx:1.21`
- A label: `id=neptune-pod`

Save the command you would use to check the pod's status to `/tmp/q02-cmd.txt`

---

## Verification

```bash
kubectl get pod neptune-pod -n neptune
kubectl describe pod neptune-pod -n neptune | grep -i "container name\|image:"
kubectl get pod neptune-pod -n neptune --show-labels
cat /tmp/q02-cmd.txt
```

---

<details>
<summary>💡 Hint</summary>

- `kubectl run` names the container the same as the pod by default — you need to use `--dry-run=client -oyaml` and edit the container name
- Don't forget to add the label with `--labels`

</details>

<details>
<summary>✅ Solution</summary>

```bash
# Scaffold YAML and fix the container name
kubectl run neptune-pod --image=nginx:1.21 --labels="id=neptune-pod" \
  --dry-run=client -oyaml -n neptune > /tmp/pod.yaml

# Edit /tmp/pod.yaml: change containers[0].name from "neptune-pod" to "neptune-container"
# Then apply:
kubectl apply -f /tmp/pod.yaml

# Save status command
echo "kubectl get pod neptune-pod -n neptune" > /tmp/q02-cmd.txt
```

</details>
