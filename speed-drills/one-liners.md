# kubectl One-Liner Speed Drills

Time yourself. Each should take < 30 seconds.

---

## Pods

**1. Create an nginx pod**
```bash
k run nginx --image=nginx
```

**2. Create a pod and expose port 80**
```bash
k run nginx --image=nginx --port=80
```

**3. Create a pod with environment variable**
```bash
k run myapp --image=busybox --env="APP_ENV=prod" -- sleep 3600
```

**4. Create a pod with labels**
```bash
k run nginx --image=nginx -l tier=frontend,app=web
```

**5. Get pod IP address**
```bash
k get pod nginx -o jsonpath='{.status.podIP}'
```

**6. Get all pod images**
```bash
k get pods -o jsonpath='{.items[*].spec.containers[*].image}'
```

**7. Delete a pod immediately**
```bash
k delete pod nginx --force --grace-period=0
```

**8. Run a command in a temporary pod and auto-delete it**
```bash
k run tmp --image=busybox --rm -it --restart=Never -- wget -qO- http://my-svc
```

---

## Deployments

**9. Create a deployment with 3 replicas**
```bash
k create deploy web --image=nginx --replicas=3
```

**10. Scale a deployment**
```bash
k scale deploy web --replicas=5
```

**11. Update deployment image**
```bash
k set image deploy/web nginx=nginx:1.21
```

**12. Rollback to previous version**
```bash
k rollout undo deploy/web
```

**13. Check rollout status**
```bash
k rollout status deploy/web
```

---

## Services

**14. Expose deployment as ClusterIP**
```bash
k expose deploy web --port=80
```

**15. Expose as NodePort**
```bash
k expose deploy web --port=80 --type=NodePort
```

**16. Check service endpoints**
```bash
k get endpoints web
```

---

## ConfigMaps & Secrets

**17. Create ConfigMap from literals**
```bash
k create cm myconfig --from-literal=KEY=value --from-literal=ENV=prod
```

**18. Create Secret from literals**
```bash
k create secret generic mysecret --from-literal=pass=s3cret
```

**19. View decoded secret**
```bash
k get secret mysecret -o jsonpath='{.data.pass}' | base64 -d
```

---

## Jobs & CronJobs

**20. Create a one-time Job**
```bash
k create job hello --image=busybox -- echo "hello world"
```

**21. Create a CronJob (every 5 min)**
```bash
k create cronjob tick --image=busybox --schedule="*/5 * * * *" -- date
```

**22. Check Job logs without finding pod name**
```bash
k logs job/hello
```

---

## RBAC

**23. Create ServiceAccount**
```bash
k create sa app-sa
```

**24. Create Role**
```bash
k create role pod-reader --verb=get,list --resource=pods
```

**25. Create RoleBinding**
```bash
k create rolebinding rb --role=pod-reader --serviceaccount=default:app-sa
```

**26. Check permissions**
```bash
k auth can-i create pods --as=system:serviceaccount:default:app-sa
```

---

## YAML Generation

**27. Generate pod YAML**
```bash
k run nginx --image=nginx $do > pod.yaml
```

**28. Generate deployment YAML**
```bash
k create deploy web --image=nginx $do > deploy.yaml
```

**29. Generate service YAML**
```bash
k expose deploy web --port=80 $do > svc.yaml
```

**30. Generate ingress YAML**
```bash
k create ingress myingress --rule="host/path=svc:80" $do > ingress.yaml
```

---

## Debugging

**31. Describe a pod**
```bash
k describe pod nginx
```

**32. Get events sorted by time**
```bash
k get events --sort-by='.lastTimestamp'
```

**33. View logs from previous crashed container**
```bash
k logs nginx --previous
```

**34. Get shell in a container**
```bash
k exec -it nginx -- sh
```

**35. Sort pods by CPU usage**
```bash
k top pods --sort-by=cpu
```

---

## Namespace

**36. Set default namespace**
```bash
k config set-context --current --namespace=dev
```

**37. Create and use namespace in one go**
```bash
k create ns dev && k config set-context --current --namespace=dev
```

---

## Challenge Round (under 60 seconds each)

**38. Create a pod with resource limits (100m CPU, 128Mi memory)**
```bash
k run limited --image=nginx $do > p.yaml
# Edit to add resources.limits, apply
```

**39. Create a NetworkPolicy that denies all ingress**
```bash
cat <<EOF | k apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes: [Ingress]
EOF
```

**40. Find which pods are NOT ready**
```bash
k get pods -A | grep -v "1/1\|2/2\|3/3\|Completed"
```
