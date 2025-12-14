#!/usr/bin/env bash
set -e

echo "::group::Installing microk8s"
echo "Starting microk8s setup..."

# Read inputs
VERSION="${INPUT_VERSION:-latest/stable}"
ADDONS="${INPUT_ADDONS:-dns,storage}"
WAIT_FOR_READY="${INPUT_WAIT_FOR_READY:-true}"
TIMEOUT="${INPUT_TIMEOUT:-300}"

echo "Configuration: version=$VERSION, addons=\"$ADDONS\", wait-for-ready=$WAIT_FOR_READY, timeout=${TIMEOUT}s"

# Detect platform
PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
if [ "$PLATFORM" != "linux" ]; then
  echo "::error::microk8s only supports Linux. Current platform: $PLATFORM"
  exit 1
fi

# Install microk8s using snap
echo "::group::Installing microk8s"
echo "Installing microk8s $VERSION..."

# Install microk8s via snap
if [ "$VERSION" = "latest" ]; then
  sudo snap install microk8s --classic --channel=latest/stable
else
  sudo snap install microk8s --classic --channel="$VERSION"
fi

# Add current user to microk8s group
echo "Adding user to microk8s group..."
sudo usermod -a -G microk8s "$USER"

# Change ownership of .kube directory
sudo chown -f -R "$USER" ~/.kube || true

# Use microk8s commands without sudo by using sg
echo "Waiting for microk8s to be ready..."
sg microk8s -c "microk8s status --wait-ready --timeout=${TIMEOUT}"

echo "✓ microk8s installed successfully"
echo "::endgroup::"

# Enable addons if specified
if [ -n "$ADDONS" ] && [ "$ADDONS" != "none" ]; then
  echo "::group::Enabling addons"
  echo "Enabling addons: $ADDONS"
  
  # Convert comma-separated list to space-separated
  ADDONS_SPACE=$(echo "$ADDONS" | tr ',' ' ')
  
  # shellcheck disable=SC2086
  sg microk8s -c "microk8s enable $ADDONS_SPACE"
  
  echo "✓ Addons enabled successfully"
  echo "::endgroup::"
fi

# Set up kubeconfig
echo "::group::Setting up kubeconfig"
mkdir -p ~/.kube
sg microk8s -c "microk8s config" > ~/.kube/config
chmod 600 ~/.kube/config

KUBECONFIG_PATH="$HOME/.kube/config"
echo "kubeconfig=$KUBECONFIG_PATH" >> "$GITHUB_OUTPUT"
echo "KUBECONFIG=$KUBECONFIG_PATH" >> "$GITHUB_ENV"
echo "KUBECONFIG exported: $KUBECONFIG_PATH"
echo "✓ Kubeconfig configured"
echo "::endgroup::"

# Create kubectl alias/symlink for convenience
if ! command -v kubectl &> /dev/null; then
  echo "Creating kubectl alias..."
  sudo snap alias microk8s.kubectl kubectl || true
fi

# Wait for cluster ready if requested
if [ "$WAIT_FOR_READY" = "true" ]; then
  echo "::group::Waiting for cluster ready"
  echo "Waiting for microk8s cluster to be ready (timeout: ${TIMEOUT}s)..."
  
  START_TIME=$(date +%s)
  
  while true; do
    ELAPSED=$(($(date +%s) - START_TIME))
    
    if [ "$ELAPSED" -gt "$TIMEOUT" ]; then
      echo "::error::Timeout waiting for cluster to be ready"
      echo "=== Diagnostic Information ==="
      sg microk8s -c "microk8s status" || true
      sg microk8s -c "microk8s kubectl get nodes -o wide" || true
      sg microk8s -c "microk8s kubectl get pods -A" || true
      sg microk8s -c "microk8s inspect" || true
      exit 1
    fi
    
    # Check if microk8s is running
    if sg microk8s -c "microk8s status --wait-ready --timeout=5" &>/dev/null; then
      echo "microk8s is running"
      
      # Check if kubectl can connect
      if kubectl get nodes --no-headers &>/dev/null; then
        echo "kubectl can connect to API server"
        
        # Check if node is Ready
        if kubectl get nodes --no-headers | grep -q " Ready "; then
          echo "Node is Ready"
          
          # Check if core pods are running
          # For microk8s, we check kube-system namespace
          if [ -n "$ADDONS" ] && [ "$ADDONS" != "none" ]; then
            # If DNS addon is enabled, check if it's running
            if echo "$ADDONS" | grep -q "dns"; then
              if kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -q "Running"; then
                echo "CoreDNS is running"
              else
                echo "Waiting for CoreDNS to be running..."
                sleep 5
                continue
              fi
            fi
          fi
          
          # Check that there are no critical pods in Error/CrashLoopBackOff state
          # Use awk to check the STATUS column (3rd column) specifically
          FAILING_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | awk '$3 ~ /Error|CrashLoopBackOff|ImagePullBackOff/ {print $0}' || true)
          
          if [ -z "$FAILING_PODS" ]; then
            echo "No critical pods failing"
            
            # Show cluster info
            echo "=== Cluster Status ==="
            kubectl get nodes
            kubectl get pods -A
            
            echo "✓ microk8s cluster is fully ready!"
            echo "::endgroup::"
            break
          else
            echo "Some critical pods are failing, waiting..."
            echo "Failing pods: $FAILING_PODS"
          fi
        else
          echo "Node not Ready yet"
        fi
      else
        echo "kubectl cannot connect yet"
      fi
    else
      echo "microk8s not running yet"
    fi
    
    echo "Cluster not ready yet, waiting... (${ELAPSED}/${TIMEOUT}s)"
    sleep 5
  done
fi

echo "✓ microk8s setup completed successfully!"
