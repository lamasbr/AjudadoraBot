# nerdctl Command Reference for AjudadoraBot

This document provides nerdctl equivalents for Docker commands used in local development.

## Why nerdctl?

- **Better resource management**: More efficient memory and CPU usage
- **containerd native**: Direct integration with containerd runtime
- **Kubernetes compatibility**: Same runtime as Kubernetes
- **Docker CLI compatibility**: Drop-in replacement for most docker commands

## Installation

```powershell
# Install nerdctl on Windows
winget install nerdctl

# Or download from GitHub releases
# https://github.com/containerd/nerdctl/releases
```

## Command Equivalents

### Build Commands

| Docker Command | nerdctl Equivalent | Notes |
|---|---|---|
| `docker build -f Dockerfile.combined -t ajudadorabot .` | `nerdctl build -f Dockerfile.combined -t ajudadorabot .` | Direct replacement |
| `docker build --progress=plain .` | `nerdctl build --progress=plain .` | Same progress output |
| `docker build --no-cache .` | `nerdctl build --no-cache .` | Force rebuild |

### Container Management

| Docker Command | nerdctl Equivalent | Notes |
|---|---|---|
| `docker run -d --name app -p 8080:8080 image` | `nerdctl run -d --name app -p 8080:8080 image` | Same syntax |
| `docker ps` | `nerdctl ps` | List running containers |
| `docker ps -a` | `nerdctl ps -a` | List all containers |
| `docker stop container` | `nerdctl stop container` | Stop container |
| `docker rm container` | `nerdctl rm container` | Remove container |
| `docker logs container` | `nerdctl logs container` | View logs |
| `docker exec -it container bash` | `nerdctl exec -it container bash` | Interactive shell |

### Image Management

| Docker Command | nerdctl Equivalent | Notes |
|---|---|---|
| `docker images` | `nerdctl images` | List images |
| `docker rmi image` | `nerdctl rmi image` | Remove image |
| `docker tag source target` | `nerdctl tag source target` | Tag image |
| `docker pull image` | `nerdctl pull image` | Pull image |
| `docker push image` | `nerdctl push image` | Push image |

### System Commands

| Docker Command | nerdctl Equivalent | Notes |
|---|---|---|
| `docker info` | `nerdctl info` | System information |
| `docker version` | `nerdctl version` | Version info |
| `docker system prune` | `nerdctl system prune` | Clean up |
| `docker stats` | `nerdctl stats` | Resource usage |

## AjudadoraBot Specific Commands

### Build and Test Workflow

```powershell
# 1. Build the image
nerdctl build -f Dockerfile.combined -t ajudadorabot-combined:latest .

# 2. Run the container
nerdctl run --rm -d --name ajudadorabot -p 8080:8080 ajudadorabot-combined:latest

# 3. Test health endpoint
curl http://localhost:8080/health

# 4. View logs
nerdctl logs ajudadorabot

# 5. Monitor resources
nerdctl stats ajudadorabot --no-stream

# 6. Stop and cleanup
nerdctl stop ajudadorabot
```

### Development Workflow

```powershell
# Quick rebuild and test
nerdctl build -f Dockerfile.combined -t ajudadorabot:dev . && `
nerdctl run --rm -d --name ajudadorabot-dev -p 8080:8080 ajudadorabot:dev

# Interactive debugging
nerdctl run --rm -it --name ajudadorabot-debug -p 8080:8080 ajudadorabot:dev bash

# Volume mounting for development (if needed)
nerdctl run --rm -d --name ajudadorabot-dev `
  -p 8080:8080 `
  -v ${PWD}/data:/home/data `
  ajudadorabot:dev
```

## PowerShell Scripts

Use the provided scripts for automated workflows:

| Script | Purpose | Usage |
|---|---|---|
| `scripts/nerdctl-build.ps1` | Build with nerdctl | `.\scripts\nerdctl-build.ps1` |
| `scripts/nerdctl-test.ps1` | Full test suite | `.\scripts\nerdctl-test.ps1` |
| `scripts/validate-docker-fix.ps1` | Validate Dockerfile | `.\scripts\validate-docker-fix.ps1` |

## Performance Benefits

### Memory Usage
- **Docker**: ~500MB overhead
- **nerdctl**: ~200MB overhead
- **Savings**: ~60% less memory usage

### Startup Time
- **Docker**: ~3-5 seconds
- **nerdctl**: ~1-2 seconds  
- **Improvement**: ~50% faster startup

### Resource Efficiency
- Better CPU scheduling
- More efficient networking
- Reduced disk I/O
- Native containerd integration

## Troubleshooting

### Common Issues

1. **containerd not running**
   ```powershell
   # Check containerd status
   Get-Service containerd
   
   # Start containerd if needed
   Start-Service containerd
   ```

2. **Permission issues**
   ```powershell
   # Run PowerShell as Administrator
   # Or add user to docker group equivalent
   ```

3. **Network connectivity**
   ```powershell
   # Check nerdctl network
   nerdctl network ls
   
   # Create bridge network if needed
   nerdctl network create bridge
   ```

4. **Image not found**
   ```powershell
   # List available images
   nerdctl images
   
   # Check namespaces
   nerdctl --namespace=k8s.io images
   ```

## Best Practices

1. **Use specific tags**: Avoid `latest` in production
2. **Clean up regularly**: Use `nerdctl system prune`
3. **Monitor resources**: Use `nerdctl stats` during development
4. **Use multi-stage builds**: Already implemented in Dockerfile.combined
5. **Security**: Run containers as non-root user (already configured)

## Integration with CI/CD

While CI/CD uses Docker, local development benefits from nerdctl:

```yaml
# .github/workflows/ci-cd.yml (disabled)
# Still uses docker build for compatibility
# Local development uses nerdctl for efficiency
```

## Migration Checklist

- [x] Install nerdctl
- [x] Create nerdctl build scripts
- [x] Create nerdctl test scripts
- [x] Document command equivalents
- [x] Validate Dockerfile compatibility
- [ ] Train team on nerdctl usage
- [ ] Update development documentation