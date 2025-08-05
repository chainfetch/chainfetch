#!/bin/bash

# Ollama Performance Monitoring Script
# Monitors resources during load testing to identify bottlenecks

echo "🔍 Starting Ollama performance monitoring..."
echo "📊 Tracking: CPU, Memory, GPU, Network, Pod health"
echo

# Configuration
MONITOR_INTERVAL=5  # seconds between measurements
LOG_FILE="ollama-performance-$(date +%Y%m%d-%H%M%S).log"

# Create monitoring log
exec > >(tee -a "$LOG_FILE")
exec 2>&1

# Function to get timestamp
timestamp() {
    date '+%H:%M:%S'
}

# Function to monitor pod resources
monitor_pods() {
    echo "$(timestamp) === POD RESOURCES ==="
    export KUBECONFIG=/Users/olivier/Desktop/kubeconfig
    kubectl top pod -n chainfetch -l app=ollama --no-headers | while read line; do
        echo "$(timestamp) POD: $line"
    done
    
    echo "$(timestamp) === POD STATUS ==="
    kubectl get pods -n chainfetch -l app=ollama --no-headers | while read line; do
        echo "$(timestamp) STATUS: $line"
    done
}

# Function to monitor GPU usage
monitor_gpu() {
    echo "$(timestamp) === GPU UTILIZATION ==="
    export KUBECONFIG=/Users/olivier/Desktop/kubeconfig
    
    # Get GPU usage from one of the pods
    POD_NAME=$(kubectl get pods -n chainfetch -l app=ollama --no-headers | head -1 | awk '{print $1}')
    if [[ -n "$POD_NAME" ]]; then
        GPU_INFO=$(kubectl exec -n chainfetch "$POD_NAME" -c ollama -- nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits 2>/dev/null)
        if [[ -n "$GPU_INFO" ]]; then
            echo "$(timestamp) GPU: Util=${GPU_INFO%,*}%, Memory=$(echo $GPU_INFO | cut -d, -f2)/$(echo $GPU_INFO | cut -d, -f3)MB, Temp=$(echo $GPU_INFO | cut -d, -f4)°C, Power=$(echo $GPU_INFO | cut -d, -f5)W"
        else
            echo "$(timestamp) GPU: Unable to get GPU metrics"
        fi
    fi
}

# Function to monitor network and service
monitor_network() {
    echo "$(timestamp) === SERVICE STATUS ==="
    export KUBECONFIG=/Users/olivier/Desktop/kubeconfig
    
    # Check service endpoints
    ENDPOINTS=$(kubectl get endpoints ollama -n chainfetch -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null)
    ENDPOINT_COUNT=$(echo "$ENDPOINTS" | wc -w)
    echo "$(timestamp) SERVICE: $ENDPOINT_COUNT endpoints ready"
    
    # Check ingress
    INGRESS_STATUS=$(kubectl get ingress ollama-protected-ingress -n chainfetch --no-headers 2>/dev/null | awk '{print $4}')
    echo "$(timestamp) INGRESS: $INGRESS_STATUS"
}

# Function to monitor system resources
monitor_system() {
    echo "$(timestamp) === NODE RESOURCES ==="
    export KUBECONFIG=/Users/olivier/Desktop/kubeconfig
    
    # Node resource usage
    NODE_INFO=$(kubectl top node --no-headers 2>/dev/null)
    if [[ -n "$NODE_INFO" ]]; then
        echo "$(timestamp) NODE: $NODE_INFO"
    fi
    
    # Check for any resource pressure
    kubectl describe nodes 2>/dev/null | grep -E "(Pressure|OutOf)" | head -5 | while read line; do
        echo "$(timestamp) PRESSURE: $line"
    done
}

# Function to check for errors in pod logs
monitor_errors() {
    echo "$(timestamp) === ERROR MONITORING ==="
    export KUBECONFIG=/Users/olivier/Desktop/kubeconfig
    
    # Check recent errors in all Ollama pods
    kubectl get pods -n chainfetch -l app=ollama --no-headers | while read pod_line; do
        POD_NAME=$(echo "$pod_line" | awk '{print $1}')
        ERROR_COUNT=$(kubectl logs "$POD_NAME" -n chainfetch --since=30s 2>/dev/null | grep -i error | wc -l)
        if [[ $ERROR_COUNT -gt 0 ]]; then
            echo "$(timestamp) ERRORS: $POD_NAME has $ERROR_COUNT errors in last 30s"
        fi
    done
}

# Function to analyze performance metrics
analyze_performance() {
    echo "$(timestamp) === PERFORMANCE ANALYSIS ==="
    export KUBECONFIG=/Users/olivier/Desktop/kubeconfig
    
    # Check if pods are hitting resource limits
    kubectl get pods -n chainfetch -l app=ollama -o json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for pod in data['items']:
    name = pod['metadata']['name']
    containers = pod.get('status', {}).get('containerStatuses', [])
    for container in containers:
        if container['name'] == 'ollama':
            restarts = container.get('restartCount', 0)
            state = container.get('state', {})
            if restarts > 0:
                print(f'$(timestamp) RESTART: {name} has {restarts} restarts')
            if 'waiting' in state:
                reason = state['waiting'].get('reason', 'Unknown')
                print(f'$(timestamp) WAITING: {name} waiting due to {reason}')
" 2>/dev/null
}

# Main monitoring loop
echo "$(timestamp) ============================================="
echo "$(timestamp) STARTING PERFORMANCE MONITORING"
echo "$(timestamp) Monitoring interval: ${MONITOR_INTERVAL}s"
echo "$(timestamp) Log file: $LOG_FILE" 
echo "$(timestamp) ============================================="

# Initial baseline measurement
monitor_pods
monitor_gpu
monitor_network
monitor_system
monitor_errors
analyze_performance

echo "$(timestamp) ============================================="
echo "$(timestamp) CONTINUOUS MONITORING STARTED"
echo "$(timestamp) Press Ctrl+C to stop monitoring"
echo "$(timestamp) ============================================="

# Continuous monitoring
while true; do
    sleep $MONITOR_INTERVAL
    
    echo
    echo "$(timestamp) === MONITORING CYCLE ==="
    monitor_pods
    monitor_gpu
    monitor_network
    analyze_performance
    
    # Every 3rd cycle, do deeper monitoring
    if (( $(date +%s) % 15 == 0 )); then
        monitor_system
        monitor_errors
    fi
done 