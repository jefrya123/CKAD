# Quiz: Domain 2 — Application Deployment

## Q1: What are the two deployment strategies? When would you use Recreate?

<details>
<summary>Answer</summary>

- **RollingUpdate** (default) — gradual replacement, zero downtime
- **Recreate** — kills all old pods, then creates new ones

Use Recreate when you can't have two versions running simultaneously (e.g., database schema changes, shared volume conflicts).

</details>

## Q2: Write the command to rollback a deployment to revision 3.

<details>
<summary>Answer</summary>

```bash
kubectl rollout undo deployment/myapp --to-revision=3
```

</details>

## Q3: What does `maxSurge: 1` and `maxUnavailable: 0` mean for a rolling update?

<details>
<summary>Answer</summary>

- **maxSurge: 1** — at most 1 extra pod above the desired count during update
- **maxUnavailable: 0** — all existing pods must stay running until new ones are ready

This is the safest strategy: new pod comes up and becomes ready before an old one is terminated. Slower but no downtime.

</details>

## Q4: How do you install a Helm chart with custom values from a file?

<details>
<summary>Answer</summary>

```bash
helm install my-release bitnami/nginx -f custom-values.yaml
```

</details>

## Q5: What's the difference between `helm template` and `helm install --dry-run`?

<details>
<summary>Answer</summary>

- **`helm template`** — renders YAML locally, no server contact, no validation
- **`helm install --dry-run`** — sends to server for validation but doesn't install

Use `template` for offline rendering, `--dry-run` to validate against the cluster.

</details>

## Q6: Explain blue/green deployment. How do you switch traffic?

<details>
<summary>Answer</summary>

Run two full deployments (blue = current, green = new). A Service points to blue. When green is ready, patch the Service selector to point to green:

```bash
kubectl patch svc myapp -p '{"spec":{"selector":{"version":"green"}}}'
```

Instant switch. Rollback = point back to blue.

</details>

## Q7: In a canary deployment with 9 stable pods and 1 canary pod, what percentage of traffic goes to canary?

<details>
<summary>Answer</summary>

~10%. The service load-balances across all 10 pods equally. 1 out of 10 = 10%.

</details>

## Q8: What kubectl command previews kustomize output without applying?

<details>
<summary>Answer</summary>

```bash
kubectl kustomize ./overlays/prod/
```

To apply: `kubectl apply -k ./overlays/prod/`

</details>

## Q9: How do you check the history of Helm releases?

<details>
<summary>Answer</summary>

```bash
helm history my-release
```

</details>

## Q10: What does `helm upgrade --install` do?

<details>
<summary>Answer</summary>

Upgrades the release if it exists, or installs it if it doesn't. Idempotent — safe to run multiple times.

</details>
