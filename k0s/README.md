# 📦 FetchSERP – k0s Kubernetes Manifests

These manifests spin up the full **FetchSERP stack** (Rails app + workers + auxiliary services) on a **single-node or multi-node [k0s](https://k0sproject.io/)** cluster.

> ⚠️ **Templates only** – replace placeholder values (image tags, domain names, secrets) before you deploy to production.

---

## What's inside?

| File | Purpose |
|------|---------|
| `namespace.yaml` | Isolates everything under the `fetchserp` namespace |
| `configmap.yaml` | Cluster-wide *non-secret* ENV (DB host, feature service hosts, etc.) |
| `secret-sample.yaml` | **Template** for sensitive keys ... |->| `secret.yaml` | All sensitive keys (Rails master key, DB password, tokens, GHCR dockerconfig) |
| `deployment-db.yaml` | Postgres 15 Deployment + Service (uses PVC `postgres-data`) |
| `postgres-pvc.yaml` | PersistentVolumeClaim (10 Gi, RWO) for database storage |
| `deployment-web.yaml` | Rails / Puma app (port **80**) + Service |
| `deployment-job.yaml` | Background workers (`bin/jobs`) running SolidQueue |
| `deployment-google-serp.yaml` | Headless Google-SERP scraping micro-service + Service |
| `deployment-mcp-server.yaml` | MCP (Model Context Protocol) bridge server + Service |
| `ingress.yaml` | Sample NGINX ingress – edit the hostnames to match your domain |
| `kustomization.yaml` | Glue file – lets you `kubectl apply -k k0s/` |
| `metallb-public-ip.yaml` | MetalLB IPAddressPool & L2Advertisement for public VPS IP |
| `cluster-issuer.yaml` | Let's Encrypt production ClusterIssuer |

---

## Quick Start

1. 🚀 **Bootstrap k0s (single-node demo)**
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://get.k0s.sh | sudo sh
   # for multi node :
   # on the controller server :
   k0s install controller --enable-worker
   k0s start
   k0s token create --role=controller
   k0s token create --role=worker
   # on the worker server :
   echo "<PASTE_TOKEN_HERE>" > /tmp/k0s-token
   k0s install worker --token-file /tmp/k0s-token
   k0s start
   # for single node :
   k0s install controller --single
   k0s start
   export KUBECONFIG=/var/lib/k0s/pki/admin.conf
   # to allow running workload on controller node : 
   k0s kubectl taint nodes ubuntu-8gb-nbg1-1 node-role.kubernetes.io/control-plane:NoSchedule-
   ```

2. 💾 **Install a default StorageClass (local-path provisioner)**  
   *k0s ships without a default dynamic volume provisioner.  
   The Postgres PVC (`postgres-data`) needs one, so let's install [local-path-provisioner](https://github.com/rancher/local-path-provisioner).*

   ```bash
   k0s kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.9.1/deploy/longhorn.yaml
   # 1. Install the local-path provisioner
   k0s kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

   # 2. Mark it as the default StorageClass
   k0s kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

   # 3. Verify
   k0s kubectl get storageclass
   ```

3. 🌐 **Install Ingress Controller + LoadBalancer (NGINX & MetalLB)**
   ```bash
   # 1. Install the NGINX Ingress controller
   k0s kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml

   # 2. Wait until the ingress controller service has an external IP/hostname
   k0s kubectl get svc -n ingress-nginx

   # 3. Install MetalLB so that Service type=LoadBalancer works on bare-metal
   k0s kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml

   # 4. Install cert manager
   k0s kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml

   # 5. Replace with server ip
   - metallb-public-ip.yaml
   - metallb-config.yaml
   - step 4 and 10.6
   ```


4. 📂 **Copy manifests to the node** (skip if you edit files directly on the server)
   ```bash
   scp -r k0s/ root@91.99.173.214:/root/
   ```


5. 📨 **Install cert-manager ClusterIssuer** (once per cluster)
   ```bash
   k0s kubectl apply -f k0s/cluster-issuer.yaml
   ```

6. 🔐 **Edit Secrets**
   ```bash
   # Edit /root/k0s/secret.yaml on the server → add base64-encoded creds
   export GH_USER=
   export CR_PAT=

   # Create docker config JSON and base64 encode it (remove newline)
   echo -n '{
   "auths": {
      "ghcr.io": {
         "username": "'"$GH_USER"'",
         "password": "'"$CR_PAT"'",
         "auth": "'"$(echo -n "$GH_USER:$CR_PAT" | base64)"'"
      }
   }
   }' | base64 | tr -d '\n'
   ```

7. 📦 **Deploy Everything**
   ```bash
   k0s kubectl apply -k /root/k0s/
   # Apply only the MetalLB address-pool YAML (resides in different namespace)
   k0s kubectl apply -f /root/k0s/metallb-config.yaml   # goes to metallb-system
   k0s kubectl apply -f /root/k0s/metallb-public-ip.yaml   # goes to metallb-system
   ```

8. 📊 **Verify**
   ```bash
   k0s kubectl -n fetchserp get deploy,po,svc
   ```

9. 📌 **Pin the Ingress-NGINX Controller to a Specific Node**  
   By default the NGINX ingress controller can be scheduled on any worker.  
   If you want to make sure it always runs on the main node (e.g. `ubuntu-8gb-nbg1-2`)
   add a `nodeSelector` to the Deployment and restart it.
   0) Check on which node is ingress :
   ```bash
   k0s kubectl get pods -n ingress-nginx -o wide
   ```

   1) Edit the controller Deployment:
   ```bash
   k0s kubectl edit deployment ingress-nginx-controller -n ingress-nginx
   ```

   2) In the editor, scroll down to the `spec.template.spec` section and add:
   ```yaml
     nodeSelector:
       kubernetes.io/hostname: ubuntu-8gb-nbg1-2
   ```

   3) Save & exit the editor, then restart the pods so the change takes effect:
   ```bash
   k0s kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx
   ```

10. 🔄 **Regenerate TLS Certificate (Let’s Encrypt)**  
   If cert-manager got stuck or you need to force-renew the certificate for  
   `fetchserp.com`, delete the existing objects and let cert-manager re-issue them:

   ```bash
   # 1) Remove the current Certificate resource
   k0s kubectl delete certificate fetchserp-tls -n fetchserp

   # 2) Remove any related (failed / pending) CertificateRequest objects
   k0s kubectl delete certificaterequest -n fetchserp --all

   # 3) Watch the new Certificate being created and issued
   k0s kubectl describe certificate fetchserp-tls -n fetchserp
   ```



9. 🌐 **Reach the App**
   • With Ingress: point `A`/`CNAME` records to your node IP.  
   • For localhost testing:
   ```bash
   k0s kubectl -n fetchserp port-forward svc/fetchserp-web 8080:80
   open http://localhost:8080
   ```

10. 📈 **Install Monitoring Stack (Prometheus + Grafana)**
   ```bash
   # 1) Install Helm (once per node)
   snap install helm --classic

   # 2) Add Prometheus Community Helm repo and update
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo update

   # 3) Create a dedicated namespace
   k0s kubectl create namespace monitoring

   # 4) Deploy kube-prometheus-stack with 7-day retention & 2 Gi persistent storage
   export KUBECONFIG=/var/lib/k0s/pki/admin.conf
   helm install kps prometheus-community/kube-prometheus-stack \
     --namespace monitoring \
     --set prometheus.prometheusSpec.retention="7d" \
     --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=2Gi \
     --set grafana.enabled=true

   # 5) Port-forward Grafana (inside the cluster → server)
   k0s kubectl apply -f /root/k0s/grafana-ingress.yaml
   k0s kubectl --namespace monitoring port-forward svc/kps-grafana 3000:80

   # 6) Tunnel the port from the server → your laptop
   ssh -L 3000:localhost:3000 root@91.99.173.214

   # Now open http://localhost:3000 (default username/password: admin/prom-operator)
   ```

11. 🚀 **Deploy a New Version**

   ```bash
   ssh root@91.99.173.214

   # Build the image for linux/amd64 and push it to GHCR
   docker build --platform=linux/amd64 -t ghcr.io/dm0lz/chainfetch:latest --push .

   # Roll out the new image to the running workloads
   k0s kubectl rollout restart deployment fetchserp-web  -n fetchserp
   k0s kubectl rollout restart deployment fetchserp-jobs -n fetchserp

   # delete pods
   k0s kubectl delete pods -n fetchserp -l app=fetchserp-web
   k0s kubectl delete pods -n fetchserp -l app=fetchserp-jobs

   ```
12. 🗂️ **Access Longhorn UI**

   ```bash
   # 1) Port-forward the Longhorn front-end service on the server
   k0s kubectl -n longhorn-system port-forward svc/longhorn-frontend 8000:80

   # 2) Tunnel port 8000 from the server → your laptop
   ssh -L 8000:localhost:8000 root@91.99.173.214

   # Now open http://localhost:8000 in your browser
   ```


---

## Customisation Cheat-Sheet

| Task | Where |
|------|-------|
| Change container images | Each `deployment-*.yaml` → `spec.template.spec.containers[].image` |
| Persist Postgres data | `postgres-pvc.yaml` (storage size/class) |
| Scale replicas | `replicas:` field in each deployment |
| Tune CPU/MEM | `resources.requests/limits` in containers |
| Different environment (staging/prod) | Use Kustomize overlays or Helm |

---

## Cleanup
```bash
kubectl delete -k k0s/
```

Happy crawling! 🕷️ 