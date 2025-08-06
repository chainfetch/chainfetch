# 🔧 Kubernetes Cheatsheet

## **Setup**
```bash
export KUBECONFIG=/Users/olivier/Desktop/kubeconfig
```

## **📦 Pods & Basic Operations**
```bash
# List pods
kubectl get pods -n chainfetch
kubectl get pods --all-namespaces

# Describe pod
kubectl describe pod <pod-name> -n chainfetch

# Connect to pod
kubectl exec -it chainfetch-web-75574c7ffd-nc8ds -n chainfetch -- /bin/bash

# View logs
kubectl logs <pod-name> -n chainfetch -f

# Delete pod
kubectl delete pod <pod-name> -n chainfetch
```

## **📊 Resource Monitoring**
```bash
# Node resource usage
kubectl top nodes
kubectl get nodes
kubectl describe node ubuntu-2404-noble-amd64-base

# Pod resource usage
kubectl top pods -n chainfetch
kubectl top pods --all-namespaces

# Continuous monitoring
watch -n 1 kubectl top pods -n chainfetch
watch -n 1 kubectl top pods --all-namespaces
```

## **🎮 GPU Monitoring**
```bash
# Check GPU from ollama pod
kubectl exec -it ollama-5d8455bbc8-rzx5t -n chainfetch -- nvidia-smi

# Continuous GPU monitoring
kubectl exec -it ollama-5d8455bbc8-rzx5t -n chainfetch -- watch -n 1 nvidia-smi
kubectl exec -it ollama-5d8455bbc8-rzx5t -n chainfetch -- nvidia-smi -l 1

# GPU resource allocation
kubectl get pods -o custom-columns="NAME:.metadata.name,GPU_REQUEST:.spec.containers[*].resources.requests.nvidia\.com/gpu,GPU_LIMIT:.spec.containers[*].resources.limits.nvidia\.com/gpu" --all-namespaces
```

## **💾 PVC & Storage Management**
```bash
# List PVCs
kubectl get pvc -n chainfetch
kubectl get pvc --all-namespaces

# Describe PVC details
kubectl describe pvc postgres-data-longhorn -n chainfetch

# List Persistent Volumes
kubectl get pv
kubectl describe pv <pv-name>

# Delete PVC (careful!)
kubectl delete pvc <pvc-name> -n chainfetch

# Check storage usage by pods
kubectl get pods -o custom-columns="NAME:.metadata.name,VOLUMES:.spec.volumes[*].persistentVolumeClaim.claimName" -n chainfetch
```

## **🗂️ Longhorn Volume Management**
```bash
# List Longhorn volumes
kubectl get volume -n longhorn-system

# Describe Longhorn volume
kubectl describe volume <volume-name> -n longhorn-system

# Delete Longhorn volume (nuclear option!)
kubectl delete volume <volume-name> -n longhorn-system

# Check Longhorn nodes and storage
kubectl get nodes.longhorn.io -n longhorn-system
kubectl describe nodes.longhorn.io ubuntu-2404-noble-amd64-base -n longhorn-system

# Check Longhorn system pods
kubectl get pods -n longhorn-system

# Longhorn volume status overview
kubectl get volume -n longhorn-system -o custom-columns="NAME:.metadata.name,STATE:.status.state,ROBUSTNESS:.status.robustness,SIZE:.spec.size"
```

## **🔄 Deployment Management**
```bash
# Get deployments
kubectl get deployments -n chainfetch

# Scale deployments
kubectl scale deployment postgres -n chainfetch --replicas=0
kubectl scale deployment postgres -n chainfetch --replicas=1
kubectl scale deployment chainfetch-web -n chainfetch --replicas=0
kubectl scale deployment chainfetch-jobs -n chainfetch --replicas=0

# Apply manifests
kubectl apply -f k0s/deployment-rails.yaml
kubectl apply -f k0s/deployment-rails.yaml --dry-run=client

# Restart deployments
kubectl rollout restart deployment <deployment-name> -n chainfetch
```

## **🏷️ Storage Classes**
```bash
# List storage classes
kubectl get storageclass

# Describe storage class
kubectl get storageclass longhorn-qdrant-distributed -o yaml
kubectl describe storageclass longhorn-qdrant-distributed

# Check replica configuration
kubectl get storageclass longhorn-qdrant-distributed -o jsonpath='{.parameters.numberOfReplicas}'
```

## **🔍 Troubleshooting Commands**
```bash
# Check events
kubectl get events -n chainfetch --sort-by='.lastTimestamp'
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Check all resources in namespace
kubectl get all -n chainfetch

# Port forward for local access
kubectl port-forward pod/<pod-name> 3000:3000 -n chainfetch
kubectl port-forward service/chainfetch-web 3000:80 -n chainfetch

# Copy files to/from pods
kubectl cp <pod-name>:/path/to/file ./local-file -n chainfetch
kubectl cp ./local-file <pod-name>:/path/to/file -n chainfetch

# Check pod environment variables
kubectl exec <pod-name> -n chainfetch -- env

# Check pod filesystem
kubectl exec <pod-name> -n chainfetch -- df -h
kubectl exec <pod-name> -n chainfetch -- ls -la /var/lib/postgresql/data
```

## **⚠️ Emergency Storage Cleanup**
```bash
# List volumes by status
kubectl get pv | grep Released
kubectl get pv | grep Available
kubectl get pv | grep Bound

# Delete all released PVs (frees up space)
kubectl get pv | grep Released | awk '{print $1}' | xargs kubectl delete pv

# Force delete stuck PVC
kubectl patch pvc <pvc-name> -p '{"metadata":{"finalizers":null}}' -n chainfetch

# Clean up orphaned Longhorn volumes
kubectl get volume -n longhorn-system | grep "faulted\|unknown"
kubectl get volume -n longhorn-system | grep "faulted\|unknown" | awk '{print $1}' | xargs kubectl delete volume -n longhorn-system

# Nuclear option: Delete all faulted/unknown volumes
kubectl delete volume $(kubectl get volume -n longhorn-system | grep "faulted\|unknown" | awk '{print $1}') -n longhorn-system
```

## **🔒 Secrets & ConfigMaps**
```bash
# List secrets
kubectl get secrets -n chainfetch

# Describe secret
kubectl describe secret chainfetch-secrets -n chainfetch

# List configmaps
kubectl get configmaps -n chainfetch

# View configmap
kubectl get configmap chainfetch-config -n chainfetch -o yaml
```

## **🌐 Services & Ingress**
```bash
# List services
kubectl get services -n chainfetch

# Describe service
kubectl describe service chainfetch-web -n chainfetch

# List ingress
kubectl get ingress -n chainfetch

# Describe ingress
kubectl describe ingress chainfetch-web-ingress -n chainfetch
```

## **📈 Advanced Monitoring**
```bash
# Resource usage with sorting
kubectl top pods --all-namespaces --sort-by=cpu
kubectl top pods --all-namespaces --sort-by=memory

# Node capacity and allocation
kubectl describe nodes | grep -A 5 "Allocated resources"

# Pod resource requests and limits
kubectl get pods -o custom-columns="NAME:.metadata.name,CPU_REQ:.spec.containers[*].resources.requests.cpu,MEM_REQ:.spec.containers[*].resources.requests.memory,CPU_LIM:.spec.containers[*].resources.limits.cpu,MEM_LIM:.spec.containers[*].resources.limits.memory" -n chainfetch

# Continuous monitoring dashboard
watch -n 2 "kubectl top nodes && echo '---' && kubectl top pods -n chainfetch"
```

## **🚀 Quick Actions**
```bash
# Restart all chainfetch apps
kubectl rollout restart deployment chainfetch-web chainfetch-jobs -n chainfetch

# Scale down all chainfetch apps
kubectl scale deployment chainfetch-web chainfetch-jobs postgres -n chainfetch --replicas=0

# Scale up all chainfetch apps
kubectl scale deployment postgres -n chainfetch --replicas=1
kubectl scale deployment chainfetch-web chainfetch-jobs -n chainfetch --replicas=1

# Complete app restart (scale down, wait, scale up)
kubectl scale deployment chainfetch-web chainfetch-jobs -n chainfetch --replicas=0 && sleep 10 && kubectl scale deployment chainfetch-web chainfetch-jobs -n chainfetch --replicas=1
```

## **💡 Tips**
- Always set `KUBECONFIG` environment variable first
- Use `--dry-run=client` to test commands before executing
- Use `watch` for continuous monitoring
- Check events when troubleshooting pod issues
- Scale deployments to 0 before deleting PVCs
- Clean up orphaned Longhorn volumes to free storage space
- Use `kubectl describe` for detailed information about resources 