# Setup microk8s Action

A GitHub Action for installing and configuring [microk8s](https://microk8s.io/) - a lightweight, pure-upstream Kubernetes designed for developers, edge, IoT, and CI/CD.

## Features

- ✅ Automatic installation of microk8s via snap
- ✅ Support for different versions and channels
- ✅ Easy addon management (dns, storage, ingress, etc.)
- ✅ Waits for cluster readiness
- ✅ Outputs kubeconfig path for easy integration
- ✅ **Simple bash-based implementation** - No Node.js dependencies required

## Quick Start

```yaml
name: Test with microk8s

on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup microk8s
        id: microk8s
        uses: fenio/setup-microk8s@v1
      
      - name: Deploy and test
        run: |
          kubectl apply -f k8s/
          kubectl wait --for=condition=available --timeout=60s deployment/my-app
```

## Inputs

| Input | Description | Default |
|-------|-------------|---------|
| `version` | microk8s version/channel to install (e.g., `1.28`, `1.29/stable`, `latest/edge`) | `latest/stable` |
| `addons` | Comma-separated list of addons to enable (e.g., `dns,storage,ingress`) | `dns,storage` |
| `wait-for-ready` | Wait for cluster to be ready before completing | `true` |
| `timeout` | Timeout in seconds to wait for cluster readiness | `300` |
| `dns-readiness` | Wait for CoreDNS to be ready and verify DNS resolution works | `true` |

## Outputs

| Output | Description |
|--------|-------------|
| `kubeconfig` | Path to the kubeconfig file (typically `~/.kube/config`) |

## Usage Examples

### Basic Usage with Latest Version

```yaml
- name: Setup microk8s
  uses: fenio/setup-microk8s@v1
```

### Specific Kubernetes Version

```yaml
- name: Setup microk8s
  uses: fenio/setup-microk8s@v1
  with:
    version: '1.28/stable'
```

### With Custom Addons

```yaml
- name: Setup microk8s
  uses: fenio/setup-microk8s@v1
  with:
    addons: 'dns,storage,ingress,metallb'
```

### Without Addons

```yaml
- name: Setup microk8s
  uses: fenio/setup-microk8s@v1
  with:
    addons: 'none'
```

### Using Edge Channel

```yaml
- name: Setup microk8s
  uses: fenio/setup-microk8s@v1
  with:
    version: 'latest/edge'
```

### Custom Timeout

```yaml
- name: Setup microk8s
  uses: fenio/setup-microk8s@v1
  with:
    timeout: '300'  # 5 minutes
```

## Available Addons

microk8s supports many addons out of the box:

- `dns` - CoreDNS for cluster DNS resolution
- `storage` - Default hostpath storage provider
- `ingress` - NGINX Ingress Controller
- `dashboard` - Kubernetes Dashboard
- `registry` - Private container registry
- `metrics-server` - Kubernetes Metrics Server
- `prometheus` - Prometheus monitoring
- `istio` - Istio service mesh
- `metallb` - MetalLB load balancer
- `cert-manager` - Certificate management
- And many more...

Run `microk8s enable --help` to see all available addons.

## How It Works

1. Verifies the platform is Linux (microk8s requirement)
2. Installs microk8s using snap with the specified channel
3. Adds the current user to the microk8s group
4. Waits for microk8s to be ready
5. Enables specified addons
6. Exports the kubeconfig to `~/.kube/config`
7. Sets up kubectl alias for convenience
8. Optionally waits for the cluster to become fully ready

The cluster remains running after your workflow completes. This works perfectly for:
- GitHub-hosted runners (fresh VM each time)
- Self-hosted runners where you want the cluster to persist

If you need cleanup, you can add it explicitly:
```yaml
- name: Cleanup
  if: always()
  run: sudo snap remove microk8s
```

## Requirements

- **Linux only** - microk8s requires a Linux system
- Runs on `ubuntu-latest` or other Linux runners
- Requires `snap` to be installed (pre-installed on Ubuntu)
- Requires `sudo` access for snap installation

## Platform Support

microk8s only supports Linux. If you need Kubernetes on other platforms, consider:
- macOS: Use [setup-minikube](https://github.com/fenio/setup-minikube)
- Windows: Use [setup-minikube](https://github.com/fenio/setup-minikube)

## Troubleshooting

### Cluster Not Ready

If the cluster doesn't become ready in time, increase the timeout:

```yaml
- name: Setup microk8s
  uses: fenio/setup-microk8s@v1
  with:
    timeout: '300'  # 5 minutes
```

### Addon Issues

If you encounter issues with addons, you can disable them and enable manually:

```yaml
- name: Setup microk8s
  uses: fenio/setup-microk8s@v1
  with:
    addons: 'none'

- name: Enable addons manually
  run: |
    microk8s enable dns
    microk8s enable storage
```

### Permission Issues

The action automatically adds the user to the microk8s group. If you still encounter permission issues:

```yaml
- name: Fix permissions
  run: |
    sudo usermod -a -G microk8s $USER
    sg microk8s -c 'microk8s status'
```

## Development

This action is written in pure bash and requires no build step. Just edit `setup.sh` and test!

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Related Projects

- [microk8s](https://microk8s.io/) - Lightweight Kubernetes by Canonical
- [setup-k3s](https://github.com/fenio/setup-k3s) - Lightweight Kubernetes (k3s)
- [setup-minikube](https://github.com/fenio/setup-minikube) - Local Kubernetes
- [setup-k0s](https://github.com/fenio/setup-k0s) - Zero friction Kubernetes (k0s)
- [setup-kubesolo](https://github.com/fenio/setup-kubesolo) - Ultra-lightweight Kubernetes
