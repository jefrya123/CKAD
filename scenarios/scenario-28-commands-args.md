# Scenario 28: Commands and Arguments Override

**Domain:** Application Design and Build
**Time Limit:** 3 minutes

## Task

1. Create a pod called `cmd-pod` using the `busybox` image that:
   - Overrides the default command with `/bin/sh`
   - Passes arguments `-c` and `echo "Hello from command override"; sleep 3600`
2. Verify the pod is running and check its logs to see the message.
3. Create a second pod called `env-cmd-pod` using `busybox` that:
   - Uses `command: ["/bin/sh", "-c"]` and `args: ["echo $GREETING; sleep 3600"]`
   - Sets an environment variable `GREETING=Hello from env`
4. Check the logs of `env-cmd-pod` to verify the environment variable was expanded.

---

<details>
<summary>💡 Hint</summary>

In Kubernetes: `command` overrides Docker's `ENTRYPOINT`, and `args` overrides Docker's `CMD`. Environment variables in `args` are expanded by the shell, not by Kubernetes.

</details>

<details>
<summary>✅ Solution</summary>

```yaml
# Pod 1: command and args
apiVersion: v1
kind: Pod
metadata:
  name: cmd-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["/bin/sh"]
    args: ["-c", "echo 'Hello from command override'; sleep 3600"]
---
# Pod 2: args with env var
apiVersion: v1
kind: Pod
metadata:
  name: env-cmd-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["/bin/sh", "-c"]
    args: ["echo $GREETING; sleep 3600"]
    env:
    - name: GREETING
      value: "Hello from env"
```

```bash
kubectl apply -f cmd-pods.yaml

# Verify
kubectl logs cmd-pod
# Hello from command override

kubectl logs env-cmd-pod
# Hello from env
```

</details>
