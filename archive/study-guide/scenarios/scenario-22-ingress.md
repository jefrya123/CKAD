# Scenario 22: Create Ingress

**Domain:** Services & Networking
**Time Limit:** 4 minutes

## Task

1. Create a deployment `api` with image `nginx` and expose as service `api-svc` on port 80
2. Create a deployment `web` with image `httpd` and expose as service `web-svc` on port 80
3. Create an Ingress `app-ingress` with:
   - Host: `myapp.example.com`
   - Path `/api` → `api-svc:80`
   - Path `/web` → `web-svc:80`
   - IngressClassName: `nginx`

---

<details>
<summary>💡 Hint</summary>

`kubectl create ingress app-ingress --rule="myapp.example.com/api=api-svc:80" --rule="myapp.example.com/web=web-svc:80"` or write YAML.

</details>

<details>
<summary>✅ Solution</summary>

```bash
kubectl create deploy api --image=nginx
kubectl expose deploy api --name=api-svc --port=80
kubectl create deploy web --image=httpd
kubectl expose deploy web --name=web-svc --port=80
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-svc
            port:
              number: 80
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web-svc
            port:
              number: 80
```

```bash
kubectl apply -f ingress.yaml
kubectl get ingress app-ingress
kubectl describe ingress app-ingress
```

</details>
