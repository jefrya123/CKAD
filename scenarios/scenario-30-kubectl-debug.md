# Scenario 30: Debugging with Ephemeral Containers

**Domain:** Application Observability and Maintenance
**Time Limit:** 3 minutes

## Task

1. Create a pod called `debug-target` using the `nginx` image.
2. Wait for it to be running.
3. Use `kubectl debug` to attach an ephemeral container to `debug-target`:
   - Use the `busybox` image
   - Name the debug container `debugger`
   - Get an interactive shell
   - Share the process namespace with the target container
4. From the ephemeral container, verify you can see the nginx processes using `ps aux`.
5. Create a copy of `debug-target` called `debug-copy` with a debug container, using `kubectl debug` with the `--copy-to` flag.

---

<details>
<summary>💡 Hint</summary>

Use `kubectl debug -it <pod> --image=busybox --target=<container>` for ephemeral containers. Use `kubectl debug <pod> --copy-to=<new-name> --image=busybox -it` to create a debugging copy.

</details>

<details>
<summary>✅ Solution</summary>

```bash
# Create target pod
kubectl run debug-target --image=nginx
kubectl wait --for=condition=Ready pod/debug-target

# Attach ephemeral debug container (interactive session)
kubectl debug -it debug-target --image=busybox --container=debugger --target=nginx
# Inside the container:
#   ps aux    # Should show nginx processes
#   exit

# Create a copy for debugging
kubectl debug debug-target --copy-to=debug-copy --image=busybox -it -- sh
# Inside the container:
#   ps aux
#   exit

# Verify the ephemeral container was added
kubectl get pod debug-target -o jsonpath='{.spec.ephemeralContainers[*].name}'
# debugger

# Verify the copy exists
kubectl get pod debug-copy
```

</details>
