# CKAD Domain 2: Application Deployment

Work through these lessons in order. Each one builds on the last, so by the end you're deploying applications through their full lifecycle - from initial rollout to blue/green switches to Kustomize overlays. The pattern is: learn why something exists, understand how it works, then practice.

**Prerequisites:** A running cluster and `kubectl` configured.

---

## Lesson 1: Deployments and ReplicaSets

Pods on their own are fragile. If a pod dies, it stays dead. If you need three copies of your app, you have to create and manage three separate pod manifests. Deployments solve both problems.

### Why Deployments exist

A bare pod has no self-healing. If the node it's running on crashes, or if the process inside exits, the pod is gone forever. Nobody recreates it.

A **Deployment** gives you:

1. **Self-healing** - if a pod dies, a new one replaces it automatically
2. **Scaling** - declare "I want 5 replicas" and Kubernetes maintains exactly 5
3. **Rolling updates** - change the image version and pods update gradually with zero downtime
4. **Rollback** - broke something? Roll back to the previous version instantly

### How the three-layer ownership works

A Deployment doesn't manage pods directly. There's a middle layer:

```
Deployment  →  ReplicaSet  →  Pods
(desired state)  (maintains count)  (actual workload)
```

- **Deployment** - you declare the desired state (image, replicas, strategy)
- **ReplicaSet** - created by the Deployment, ensures the right number of pods exist at all times
- **Pods** - created by the ReplicaSet, run your actual containers

You almost never create ReplicaSets directly. The Deployment creates and manages them for you. When you update a Deployment, it creates a *new* ReplicaSet and scales down the old one - that's how rolling updates work (Lesson 2).

### The label-selector mechanism

The ReplicaSet finds its pods using label selectors. This is the glue:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3                    # Desired pod count
  selector:
    matchLabels:
      app: web                   # "I own pods with this label"
  template:
    metadata:
      labels:
        app: web                 # Pods get this label (must match selector)
    spec:
      containers:
      - name: nginx
        image: nginx:1.24
        ports:
        - containerPort: 80
```

The `selector.matchLabels` must match `template.metadata.labels`. If they don't, Kubernetes rejects the manifest. This is how the ReplicaSet knows which pods belong to it.

### Imperative shortcuts

For the exam, you can create Deployments fast:

```bash
# Create a deployment directly
kubectl create deployment web --image=nginx:1.24 --replicas=3

# Generate YAML to edit
kubectl create deployment web --image=nginx:1.24 --replicas=3 --dry-run=client -o yaml > deploy.yaml

# Scale an existing deployment
kubectl scale deployment web --replicas=5
```

### Exercises

**1.1** Create a deployment called `web` with 3 replicas using `nginx:1.24`. Verify that 3 pods are running and find the ReplicaSet that owns them.

<details>
<summary>Solution</summary>

```bash
kubectl create deployment web --image=nginx:1.24 --replicas=3
kubectl get deployment web
kubectl get pods -l app=web
kubectl get replicaset -l app=web
```

You should see one ReplicaSet with 3/3/3 (desired/current/ready). The pods all have names starting with the ReplicaSet name.

</details>

**1.2** Delete one of the pods from the `web` deployment. What happens? How quickly does the replacement appear?

<details>
<summary>Solution</summary>

```bash
# Get a pod name
kubectl get pods -l app=web

# Delete it
kubectl delete pod <pod-name>

# Watch the self-healing
kubectl get pods -l app=web -w
```

The ReplicaSet immediately creates a replacement pod. The count never stays at 2 for long - the controller loop detects the mismatch and reconciles. This is why you use Deployments instead of bare pods.

</details>

**1.3** Scale the `web` deployment to 5 replicas using the imperative command. Then generate the YAML for a deployment called `api` with image `httpd:2.4` and 2 replicas (don't apply it, just save the YAML to a file).

<details>
<summary>Solution</summary>

```bash
kubectl scale deployment web --replicas=5
kubectl get pods -l app=web    # Should see 5 pods

kubectl create deployment api --image=httpd:2.4 --replicas=2 --dry-run=client -o yaml > api-deploy.yaml
cat api-deploy.yaml
```

The generated YAML is a valid Deployment manifest you can edit and apply later. This is the fastest way to get a scaffold on the exam.

</details>

### Cleanup

```bash
kubectl delete deployment web
rm -f api-deploy.yaml
```

---

## Lesson 2: Rolling Updates and Rollbacks

Now you know Deployments maintain a desired number of pods. But what happens when you need to change the image version? You don't want to kill all pods and start new ones - that's downtime. Rolling updates solve this.

### Why rolling updates exist

Without a rolling update, upgrading means: delete all old pods, start new pods. Users get errors during the gap. A **rolling update** replaces pods gradually - start a few new ones, verify they're healthy, then terminate a few old ones. Traffic keeps flowing the entire time.

### How rolling updates work

When you update a Deployment (e.g., change the image), Kubernetes:

1. Creates a **new ReplicaSet** with the updated pod spec
2. Scales the new ReplicaSet **up** gradually
3. Scales the old ReplicaSet **down** gradually
4. Keeps enough pods running throughout so there's no downtime

Two parameters control the pace:

```yaml
spec:
  strategy:
    type: RollingUpdate          # Default strategy
    rollingUpdate:
      maxSurge: 1                # How many extra pods above desired count
      maxUnavailable: 1          # How many pods can be down during update
```

- **maxSurge: 1** means during the update, there can be `replicas + 1` pods total
- **maxUnavailable: 1** means at least `replicas - 1` pods must be available at all times

These can be absolute numbers or percentages (e.g., `25%`). The defaults (`25%` each) work well for most cases.

### The alternative: Recreate strategy

```yaml
spec:
  strategy:
    type: Recreate               # Kill all old, then start all new
```

This is simpler but causes downtime. Use it when your app can't handle two versions running simultaneously (e.g., database schema changes).

### Rollout commands

```bash
kubectl rollout status deployment/web    # Watch the rollout progress
kubectl rollout history deployment/web   # See revision history
kubectl rollout undo deployment/web      # Rollback to previous revision
kubectl rollout undo deployment/web --to-revision=2  # Rollback to specific revision
```

### Exercises

**2.1** Update the `web` deployment's image from `nginx:1.24` to `nginx:1.25`. Watch the rollout happen in real time.

<details>
<summary>Solution</summary>

```bash
kubectl create deployment web --image=nginx:1.24 --replicas=3
kubectl set image deployment/web nginx=nginx:1.25
kubectl rollout status deployment/web
```

You can also watch the ReplicaSets:
```bash
kubectl get replicaset -l app=web
```

You'll see two ReplicaSets - the old one scaling down to 0 and the new one scaling up to 3.

</details>

**2.2** The `nginx:1.25` version has a problem (pretend). Roll back the `web` deployment to the previous version. Verify the image is back to `nginx:1.24`.

<details>
<summary>Solution</summary>

```bash
kubectl rollout undo deployment/web
kubectl rollout status deployment/web

# Verify the image
kubectl describe deployment web | grep Image
# Or:
kubectl get deployment web -o jsonpath='{.spec.template.spec.containers[0].image}'
```

The undo creates a new rollout that uses the old ReplicaSet's pod spec. If you check `kubectl rollout history`, you'll see a new revision number.

</details>

**2.3** Create a deployment called `controlled` with `nginx:1.24`, 4 replicas, and a RollingUpdate strategy with `maxSurge: 1` and `maxUnavailable: 0` (zero-downtime guarantee). Update the image to `nginx:1.25` and watch the ReplicaSets during the rollout.

<details>
<summary>Solution</summary>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: controlled
spec:
  replicas: 4
  selector:
    matchLabels:
      app: controlled
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: controlled
    spec:
      containers:
      - name: nginx
        image: nginx:1.24
        ports:
        - containerPort: 80
```

```bash
kubectl apply -f controlled.yaml
kubectl set image deployment/controlled nginx=nginx:1.25

# Watch both ReplicaSets in real time
kubectl get replicaset -l app=controlled -w
```

With `maxUnavailable: 0`, Kubernetes always keeps 4 pods ready. It starts 1 new pod (maxSurge), waits for it to be ready, then terminates 1 old pod. Repeat until done. Slower but guarantees full capacity throughout.

</details>

**2.4** Create a deployment called `recreate-app` with `nginx:1.24`, 3 replicas, and `strategy.type: Recreate`. Update the image to `nginx:1.25`. How does this differ from what you saw in exercise 2.3?

<details>
<summary>Solution</summary>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: recreate-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: recreate-app
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: recreate-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.24
```

```bash
kubectl apply -f recreate-app.yaml
kubectl set image deployment/recreate-app nginx=nginx:1.25

kubectl get pods -l app=recreate-app -w
```

With Recreate, all 3 old pods are terminated first, then 3 new pods are created. You'll see a period where 0 pods are ready - that's downtime. Use this only when you can't have two versions running simultaneously.

</details>

### Cleanup

```bash
kubectl delete deployment web controlled recreate-app
```

---

## Lesson 3: Blue/Green and Canary Deployments

Rolling updates are automatic but you don't have much control over traffic routing. Sometimes you need more precision: test the new version completely before switching all traffic, or send just 10% of traffic to the new version first. That's where blue/green and canary patterns come in.

### Why these patterns exist

- **Rolling update**: Kubernetes decides the pace. You can't test the new version in isolation before real users hit it.
- **Blue/green**: Two full environments exist simultaneously. You test the green (new) version, then flip all traffic at once by changing the Service selector.
- **Canary**: Both versions run behind the same Service. You control the traffic split by adjusting pod ratios.

These aren't built-in Kubernetes resource types. They're patterns you implement using Deployments and Services.

### Blue/green: the traffic switch

The idea is simple. Two Deployments exist with different labels:

```yaml
# Blue deployment (current production)
metadata:
  name: app-blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue
  template:
    metadata:
      labels:
        app: myapp
        version: blue
    spec:
      containers:
      - name: app
        image: nginx:1.24
```

```yaml
# Green deployment (new version)
metadata:
  name: app-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
      - name: app
        image: nginx:1.25
```

The Service selects which version gets traffic:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp
    version: blue              # Switch to "green" to cut over
  ports:
  - port: 80
```

To switch: `kubectl patch service myapp -p '{"spec":{"selector":{"version":"green"}}}'`

Instant cutover. If something is wrong, switch back to blue.

### Canary: gradual traffic split

Instead of switching all traffic at once, you run both versions behind one Service. The Service selects on a **shared label** that both Deployments have:

```yaml
# Service selects only "app: myapp" (both versions have this)
spec:
  selector:
    app: myapp                 # No version label - matches both!
```

Traffic is distributed by pod count. If the stable Deployment has 4 replicas and the canary has 1, roughly 20% of traffic goes to the canary. Scale the canary up to get more traffic to it.

### Exercises

**3.1** Implement a blue/green deployment:
- Create deployment `app-blue` with 3 replicas of `nginx:1.24`, labels `app: myapp` and `version: blue`
- Create deployment `app-green` with 3 replicas of `nginx:1.25`, labels `app: myapp` and `version: green`
- Create a Service called `myapp` on port 80 pointing to `version: blue`
- Verify traffic goes to blue, then switch the Service to green, and verify again.

<details>
<summary>Solution</summary>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue
  template:
    metadata:
      labels:
        app: myapp
        version: blue
    spec:
      containers:
      - name: app
        image: nginx:1.24
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
      - name: app
        image: nginx:1.25
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp
    version: blue
  ports:
  - port: 80
    targetPort: 80
```

```bash
kubectl apply -f blue-green.yaml

# Verify blue is receiving traffic
kubectl get endpoints myapp    # Should show blue pod IPs

# Switch to green
kubectl patch service myapp -p '{"spec":{"selector":{"version":"green"}}}'

# Verify green is now receiving traffic
kubectl get endpoints myapp    # Should now show green pod IPs
```

</details>

**3.2** Implement a canary deployment:
- Create deployment `stable` with 4 replicas of `httpd:2.4`, label `app: webapp`
- Create deployment `canary` with 1 replica of `httpd:2.4-alpine`, label `app: webapp`
- Create a Service called `webapp` that selects `app: webapp`
- Check the endpoints to see all 5 pods - roughly 20% of traffic goes to the canary.

<details>
<summary>Solution</summary>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stable
spec:
  replicas: 4
  selector:
    matchLabels:
      app: webapp
      track: stable
  template:
    metadata:
      labels:
        app: webapp
        track: stable
    spec:
      containers:
      - name: app
        image: httpd:2.4
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
      track: canary
  template:
    metadata:
      labels:
        app: webapp
        track: canary
    spec:
      containers:
      - name: app
        image: httpd:2.4-alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: webapp
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
```

```bash
kubectl apply -f canary.yaml

# See all 5 endpoints (4 stable + 1 canary)
kubectl get endpoints webapp
kubectl get pods -l app=webapp -o wide
```

The Service load-balances across all 5 pods. Since 1 out of 5 is canary, roughly 20% of requests hit the new version.

</details>

**3.3** Promote the canary to stable: scale the `canary` deployment to 4 replicas and scale `stable` to 0. Verify all traffic now goes to the canary version.

<details>
<summary>Solution</summary>

```bash
kubectl scale deployment canary --replicas=4
kubectl scale deployment stable --replicas=0

# Verify
kubectl get pods -l app=webapp
kubectl get endpoints webapp
```

All 4 remaining pods are running the canary image. In a real scenario you'd then update the stable deployment's image to match the canary, scale it back up, and delete the canary deployment.

</details>

### Cleanup

```bash
kubectl delete deployment app-blue app-green stable canary
kubectl delete service myapp webapp
```

---

## Lesson 4: Helm Package Management

So far you've been managing individual YAML files. But real applications have many resources: Deployments, Services, ConfigMaps, Secrets, Ingresses. Managing them as separate files gets messy. Helm bundles them into a single package.

### Why Helm exists

Helm solves three problems:

1. **Packaging** - a chart bundles all the Kubernetes manifests an application needs into one unit
2. **Parameterization** - values files let you customize the same chart for different environments (dev uses 1 replica, prod uses 10)
3. **Lifecycle management** - install, upgrade, rollback, and uninstall an application as a single operation

### Key terminology

- **Chart** - a package of Kubernetes resource templates. Like an apt/yum package but for Kubernetes.
- **Release** - an installed instance of a chart. You can install the same chart multiple times with different release names.
- **Repository** - a collection of charts (like a package registry). `helm repo add` to register one.
- **Values** - the configuration that customizes a chart. Override defaults with `--set` or `-f values.yaml`.

### The Helm lifecycle

```bash
# Add a repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Search for charts
helm search repo nginx

# Install a chart (creates a release)
helm install my-release bitnami/nginx

# List installed releases
helm list

# Upgrade a release (change values or chart version)
helm upgrade my-release bitnami/nginx --set replicaCount=3

# Rollback to a previous revision
helm rollback my-release 1

# Uninstall a release
helm uninstall my-release
```

### Working with values

Every chart has default values. You can see them and override them:

```bash
# See a chart's default values
helm show values bitnami/nginx

# Override with --set (for single values)
helm install my-release bitnami/nginx --set replicaCount=2

# Override with a values file (for many values)
helm install my-release bitnami/nginx -f my-values.yaml

# Preview the rendered templates without installing
helm template my-release bitnami/nginx --set replicaCount=2

# Dry run (validates against the cluster)
helm install my-release bitnami/nginx --dry-run
```

### Exercises

**4.1** Add the bitnami repository, then install an nginx chart with release name `my-web`. Verify the release is deployed and check what Kubernetes resources it created.

<details>
<summary>Solution</summary>

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm install my-web bitnami/nginx
helm list
kubectl get all -l app.kubernetes.io/instance=my-web
```

You'll see a Deployment, ReplicaSet, Pod(s), and Service created from a single `helm install` command.

</details>

**4.2** Upgrade the `my-web` release to use 3 replicas using `--set`. Check the revision number and verify 3 pods are running.

<details>
<summary>Solution</summary>

```bash
helm upgrade my-web bitnami/nginx --set replicaCount=3
helm list    # Revision should be 2 now

kubectl get pods -l app.kubernetes.io/instance=my-web
# Should see 3 pods
```

</details>

**4.3** Roll back `my-web` to revision 1 (the original single-replica install). Verify the replica count is back to the default.

<details>
<summary>Solution</summary>

```bash
helm rollback my-web 1
helm list    # Revision should be 3 (rollback creates a new revision)

kubectl get pods -l app.kubernetes.io/instance=my-web
# Should be back to the default replica count
```

</details>

**4.4** Use `helm show values` to inspect the bitnami/nginx chart's default values. Then use `helm template` to render the manifests with `replicaCount=2` and `service.type=ClusterIP` without installing anything. Examine the rendered output.

<details>
<summary>Solution</summary>

```bash
# See all default values
helm show values bitnami/nginx | head -50

# Render templates locally
helm template preview bitnami/nginx \
  --set replicaCount=2 \
  --set service.type=ClusterIP
```

`helm template` outputs the rendered Kubernetes YAML to stdout. This is useful for reviewing what Helm would apply without actually touching the cluster. The first argument (`preview`) is the release name used for template rendering.

</details>

### Cleanup

```bash
helm uninstall my-web
```

---

## Lesson 5: Kustomize

Helm uses templates with Go syntax. Kustomize takes a different approach: it starts with plain YAML and applies transformations on top. No templates, no special syntax in your manifests. Kubernetes has Kustomize built in via `kubectl apply -k`.

### Why Kustomize exists

Imagine you have the same application deployed to dev, staging, and prod. The manifests are 90% identical - only the namespace, replica count, and image tag differ. You could:

1. Copy-paste the YAML three times (maintenance nightmare)
2. Use Helm templates (powerful but adds complexity)
3. Use Kustomize overlays (keep plain YAML, layer changes on top)

Kustomize uses a **base + overlay** model:

```
app/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   └── service.yaml
└── overlays/
    ├── dev/
    │   └── kustomization.yaml
    └── prod/
        └── kustomization.yaml
```

The base contains your standard manifests. Each overlay contains only the differences.

### How kustomization.yaml works

The base `kustomization.yaml` lists the resources:

```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
```

An overlay references the base and adds transformations:

```yaml
# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../base
namespace: production
namePrefix: prod-
replicas:
- name: web
  count: 5
images:
- name: nginx
  newTag: "1.25"
commonLabels:
  env: production
```

### Common transformations

| Transformation | What it does |
|---|---|
| `namespace` | Sets namespace on all resources |
| `namePrefix` / `nameSuffix` | Prepends/appends to all resource names |
| `replicas` | Overrides replica count for named Deployments |
| `images` | Overrides image name/tag without editing the base |
| `commonLabels` | Adds labels to all resources and selectors |
| `commonAnnotations` | Adds annotations to all resources |
| `patches` | Applies strategic merge or JSON patches |

### Using Kustomize

```bash
# Preview the rendered output (don't apply)
kubectl kustomize overlays/prod/

# Apply directly
kubectl apply -k overlays/prod/
```

### Exercises

**5.1** Create a Kustomize base for a simple web app:
- Create `base/deployment.yaml`: a Deployment called `web` with 1 replica of `nginx:1.24`
- Create `base/service.yaml`: a Service called `web` on port 80
- Create `base/kustomization.yaml` listing both resources
- Preview the output with `kubectl kustomize` and apply it.

<details>
<summary>Solution</summary>

```bash
mkdir -p base
```

```yaml
# base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.24
        ports:
        - containerPort: 80
```

```yaml
# base/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
```

```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
```

```bash
kubectl kustomize base/        # Preview
kubectl apply -k base/         # Apply
kubectl get deployment web
kubectl get service web
```

</details>

**5.2** Create a production overlay that:
- Sets namespace to `production`
- Adds `namePrefix: prod-`
- Scales replicas to 5
- Changes the image tag to `1.25`
- Adds label `env: production`

Preview the output and compare it to the base.

<details>
<summary>Solution</summary>

```bash
mkdir -p overlays/prod
```

```yaml
# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../base
namespace: production
namePrefix: prod-
replicas:
- name: web
  count: 5
images:
- name: nginx
  newTag: "1.25"
commonLabels:
  env: production
```

```bash
# Compare base vs overlay
kubectl kustomize base/
echo "---"
kubectl kustomize overlays/prod/
```

You'll see the overlay output has: `prod-web` names, `production` namespace, 5 replicas, `nginx:1.25` image, and `env: production` labels on everything - all without modifying the base files.

</details>

**5.3** Create a dev overlay that:
- Sets namespace to `development`
- Adds `namePrefix: dev-`
- Keeps replicas at 1 (same as base)
- Uses image tag `latest`
- Adds label `env: dev`

Preview both overlays side by side and compare the differences.

<details>
<summary>Solution</summary>

```bash
mkdir -p overlays/dev
```

```yaml
# overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../base
namespace: development
namePrefix: dev-
images:
- name: nginx
  newTag: latest
commonLabels:
  env: dev
```

```bash
# Compare both overlays
echo "=== DEV ==="
kubectl kustomize overlays/dev/
echo "=== PROD ==="
kubectl kustomize overlays/prod/
```

Same base YAML, two completely different outputs. Dev gets 1 replica with `latest` tag, prod gets 5 replicas with `1.25`. Neither overlay modifies the base files.

</details>

### Cleanup

```bash
kubectl delete -k base/
rm -rf base/ overlays/
```

---

## Final Challenge

This exercise combines everything from all 5 lessons. No hints - just the task.

Deploy a web application through its full lifecycle:

1. Create a Deployment called `lifecycle-app` with 3 replicas of `nginx:1.24`, using a RollingUpdate strategy with `maxSurge: 1` and `maxUnavailable: 0`. Expose it as a Service called `lifecycle-app` on port 80.

2. Perform a rolling update to `nginx:1.25`. Watch the rollout, then roll back to `nginx:1.24` and verify.

3. Create a canary Deployment called `lifecycle-canary` with 1 replica of `nginx:1.26-alpine`, using the same `app: lifecycle-app` label so the Service routes to both. Verify 4 total endpoints.

4. Set up a Kustomize structure with a base containing the stable Deployment and Service, and a `prod` overlay that adds `namePrefix: prod-`, namespace `production`, and 5 replicas.

<details>
<summary>Solution</summary>

```yaml
# lifecycle-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lifecycle-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: lifecycle-app
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: lifecycle-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.24
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: lifecycle-app
spec:
  selector:
    app: lifecycle-app
  ports:
  - port: 80
    targetPort: 80
```

```bash
# Step 1: Deploy
kubectl apply -f lifecycle-app.yaml

# Step 2: Rolling update and rollback
kubectl set image deployment/lifecycle-app nginx=nginx:1.25
kubectl rollout status deployment/lifecycle-app
kubectl rollout undo deployment/lifecycle-app
kubectl get deployment lifecycle-app -o jsonpath='{.spec.template.spec.containers[0].image}'

# Step 3: Canary
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lifecycle-canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: lifecycle-app
      track: canary
  template:
    metadata:
      labels:
        app: lifecycle-app
        track: canary
    spec:
      containers:
      - name: nginx
        image: nginx:1.26-alpine
        ports:
        - containerPort: 80
EOF

kubectl get endpoints lifecycle-app    # 4 endpoints (3 stable + 1 canary)

# Step 4: Kustomize
mkdir -p kust-base kust-overlays/prod

# Copy the deployment and service into the base
cat <<EOF > kust-base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lifecycle-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: lifecycle-app
  template:
    metadata:
      labels:
        app: lifecycle-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.24
        ports:
        - containerPort: 80
EOF

cat <<EOF > kust-base/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: lifecycle-app
spec:
  selector:
    app: lifecycle-app
  ports:
  - port: 80
    targetPort: 80
EOF

cat <<EOF > kust-base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
EOF

cat <<EOF > kust-overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../kust-base
namespace: production
namePrefix: prod-
replicas:
- name: lifecycle-app
  count: 5
commonLabels:
  env: production
EOF

kubectl kustomize kust-overlays/prod/
```

</details>

### Cleanup

```bash
kubectl delete deployment lifecycle-app lifecycle-canary
kubectl delete service lifecycle-app
rm -rf kust-base/ kust-overlays/ lifecycle-app.yaml
```

---

## Quick Reference

### Imperative shortcuts

```bash
kubectl create deployment <name> --image=<img> --replicas=<n>
kubectl scale deployment <name> --replicas=<n>
kubectl set image deployment/<name> <container>=<new-image>
kubectl rollout status deployment/<name>
kubectl rollout undo deployment/<name>
kubectl rollout history deployment/<name>
# Add --dry-run=client -o yaml to any create command for editable YAML
```

### Helm commands

```bash
helm repo add <name> <url>       # Register a chart repository
helm repo update                  # Refresh repo index
helm install <rel> <chart>        # Install a chart
helm upgrade <rel> <chart>        # Upgrade a release
helm rollback <rel> <rev>         # Rollback to a revision
helm uninstall <rel>              # Remove a release
helm list                         # List installed releases
helm show values <chart>          # View default values
helm template <rel> <chart>       # Render templates locally
```

### Kustomize commands

```bash
kubectl kustomize <dir>           # Preview rendered output
kubectl apply -k <dir>            # Apply kustomized resources
kubectl delete -k <dir>           # Delete kustomized resources
```

### Deployment strategies

| Strategy | Downtime | Use when |
|---|---|---|
| RollingUpdate | None | Default; most workloads |
| Recreate | Yes | Can't run two versions simultaneously |
| Blue/Green | None | Need full pre-switch testing |
| Canary | None | Want gradual traffic shift |

### What goes where

| Thing | YAML path |
|---|---|
| Replica count | `spec.replicas` |
| Strategy type | `spec.strategy.type` |
| Max surge | `spec.strategy.rollingUpdate.maxSurge` |
| Max unavailable | `spec.strategy.rollingUpdate.maxUnavailable` |
| Pod template labels | `spec.template.metadata.labels` |
| Label selector | `spec.selector.matchLabels` |
| Container image | `spec.template.spec.containers[].image` |
| Service selector | `spec.selector` (in Service) |
| Kustomize resources | `resources[]` (in kustomization.yaml) |
| Kustomize namespace | `namespace` (in kustomization.yaml) |
| Kustomize replicas | `replicas[]` (in kustomization.yaml) |
