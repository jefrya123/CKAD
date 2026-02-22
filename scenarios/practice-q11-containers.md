# Practice Q11 — Working with Containers (Docker/Podman)

**Mirrors KillerShell CKAD Question 11**
**Time target:** 7 minutes

---

## Setup

Create this Dockerfile in `/tmp/q11/`:

```bash
mkdir -p /tmp/q11
cat > /tmp/q11/Dockerfile <<EOF
FROM nginx:1.21
RUN echo "CKAD practice build" > /usr/share/nginx/html/index.html
EXPOSE 80
EOF
```

---

## Your Task

1. Build the Dockerfile at `/tmp/q11/Dockerfile` into an image tagged `ckad-nginx:v1`

2. Run the image locally as a container named `ckad-test` on host port `8080`

3. Confirm it serves the custom page: curl `localhost:8080` should return `CKAD practice build`

4. Save the image to a tar file at `/tmp/q11/ckad-nginx-v1.tar`

5. Stop and remove the container

---

## Verification

```bash
docker images | grep ckad-nginx
curl localhost:8080        # CKAD practice build
ls -lh /tmp/q11/ckad-nginx-v1.tar
```

---

<details>
<summary>💡 Hint</summary>

- `docker build -t ckad-nginx:v1 /tmp/q11/`
- `docker run -d --name ckad-test -p 8080:80 ckad-nginx:v1`
- `docker save ckad-nginx:v1 -o /tmp/q11/ckad-nginx-v1.tar`
- If using podman: same syntax, just replace `docker` with `podman`

</details>

<details>
<summary>✅ Solution</summary>

```bash
# Build
docker build -t ckad-nginx:v1 /tmp/q11/

# Run
docker run -d --name ckad-test -p 8080:80 ckad-nginx:v1

# Test
curl localhost:8080

# Save
docker save ckad-nginx:v1 -o /tmp/q11/ckad-nginx-v1.tar

# Cleanup
docker stop ckad-test && docker rm ckad-test
```

</details>
