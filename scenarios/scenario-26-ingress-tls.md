# Scenario 26: Ingress with TLS Termination

**Domain:** Services and Networking
**Time Limit:** 5 minutes

## Task

1. Create a deployment called `secure-web` with 2 replicas using the `nginx` image.
2. Expose it as a ClusterIP Service called `secure-web-svc` on port 80.
3. Generate a self-signed TLS certificate for the hostname `secure.example.com` (use `openssl`).
4. Create a TLS Secret called `secure-tls` from the certificate and key files.
5. Create an Ingress called `secure-ingress` that:
   - Uses the `nginx` ingress class
   - Terminates TLS for `secure.example.com` using the `secure-tls` Secret
   - Routes all traffic for `secure.example.com/` to `secure-web-svc` on port 80
6. Verify the Ingress shows the TLS configuration with `kubectl describe`.

---

<details>
<summary>💡 Hint</summary>

Use `openssl req -x509 -nodes` to generate a self-signed cert, then `kubectl create secret tls` to create the Secret. The Ingress needs both a `tls` section and a `rules` section.

</details>

<details>
<summary>✅ Solution</summary>

```bash
# Deployment and Service
kubectl create deploy secure-web --image=nginx --replicas=2
kubectl expose deploy secure-web --name=secure-web-svc --port=80

# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt -subj "/CN=secure.example.com"

# Create TLS Secret
kubectl create secret tls secure-tls --cert=tls.crt --key=tls.key
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-ingress
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - secure.example.com
    secretName: secure-tls
  rules:
  - host: secure.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-web-svc
            port:
              number: 80
```

```bash
# Verify
kubectl describe ingress secure-ingress
# TLS section should show secure.example.com → secure-tls
```

</details>
