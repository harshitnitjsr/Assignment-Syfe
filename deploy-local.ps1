#!/usr/bin/env pwsh

# Local Deployment Script for Windows PowerShell

param(
    [switch]$SkipBuild,
    [switch]$Redeploy
)

Write-Host "=== Syfe WordPress Local Deployment ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan

# Check if kubectl is available
Write-Host "Syfe WordPress Complete Deployment" -ForegroundColor Cyan
Write-Host "Checking prerequisites..." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

try {
    kubectl version --client --short 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "kubectl not found"
    }
} catch {
    Write-Host "ERROR: kubectl is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install kubectl: choco install kubernetes-cli" -ForegroundColor Yellow
    exit 1
}

# Function to check if command exists
function Test-Command($cmdname) {
    return [bool](Get-Command -Name $cmdname -ErrorAction SilentlyContinue)
}

# Check if Docker is available
try {
    if (-not (Test-Command "docker")) {
        Write-Host "❌ Docker not found! Please install Docker Desktop." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "ERROR: Docker is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Docker Desktop: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    exit 1
}

# Check if Helm is available
try {
    helm version --short 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "helm not found"
    }
} catch {
    Write-Host "ERROR: Helm is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Helm: choco install kubernetes-helm" -ForegroundColor Yellow
    exit 1
}

# Check if Kubernetes cluster is reachable
Write-Host "Checking Kubernetes cluster..." -ForegroundColor Yellow
try {
    kubectl cluster-info 2>$null | Out-Null
    Write-Host "✓ Kubernetes cluster is reachable" -ForegroundColor Green
} catch {
    Write-Host "❌ Kubernetes cluster not accessible! Please start Docker Desktop Kubernetes." -ForegroundColor Red
    exit 1
}

# Check storage class
Write-Host "Checking storage class..." -ForegroundColor Yellow
$storageClasses = kubectl get storageclass -o json 2>$null | ConvertFrom-Json

# Clean up if redeploy
if ($storageClasses.items.Count -eq 0) {
    if ($Redeploy) {
        Write-Host "WARNING: No storage class found" -ForegroundColor Red
        Write-Host "🧹 Cleaning up existing deployments..." -ForegroundColor Yellow
        helm uninstall wordpress-app -n wordpress 2>$null
        helm uninstall monitoring-stack -n monitoring 2>$null
        kubectl delete namespace wordpress --ignore-not-found=true
        kubectl delete namespace monitoring --ignore-not-found=true
    } else {
        $defaultSC = $storageClasses.items | Where-Object { $_.metadata.annotations.'storageclass.kubernetes.io/is-default-class' -eq 'true' }
        if ($defaultSC) {
            Write-Host "✓ Default storage class: $($defaultSC.metadata.name)" -ForegroundColor Green
        } else {
            Write-Host "⚠ Storage classes found but no default set" -ForegroundColor Yellow
        }
        Write-Host "✅ Cleanup completed" -ForegroundColor Green
    }
}

# Build Docker images
if (-not $SkipBuild) {
    Write-Host "=== Deploying WordPress Application ===" -ForegroundColor Cyan
    Write-Host "🔨 Building Docker images..." -ForegroundColor Yellow

    # Set script location
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    cd backend/dockerfiles/nginx
    docker build -t syfe-nginx:latest . --no-cache
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to build Nginx" -ForegroundColor Red
        exit 1
    }

    cd ../../..
    $useLocal = $true
    Write-Host "Using local development values (NodePort, reduced resources)" -ForegroundColor Yellow

    Write-Host "Building syfe-mysql..." -ForegroundColor Cyan
    cd backend/dockerfiles/mysql
    docker build -t syfe-mysql:latest . --no-cache
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to build MySQL" -ForegroundColor Red
        exit 1
    }

    Write-Host "Building syfe-wordpress..." -ForegroundColor Cyan
    cd backend/dockerfiles/wordpress
    docker build -t syfe-wordpress:latest . --no-cache
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to build WordPress" -ForegroundColor Red
        exit 1
    }

    Write-Host "✅ All images built successfully" -ForegroundColor Green
}

# Deploy WordPress application
Write-Host "🚀 Deploying WordPress application..." -ForegroundColor Yellow
cd backend/helm/wordpress-app
helm install wordpress-app . -n wordpress --create-namespace -f values-local-fixed.yaml
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ WordPress deployment failed" -ForegroundColor Red
    exit 1
}

Write-Host "✅ WordPress deployed" -ForegroundColor Green

# Deploy Monitoring
Write-Host "Installing Monitoring stack..." -ForegroundColor Yellow
cd ../../..
Set-Location (Join-Path $helmPath "monitoring-stack")

Write-Host "📊 Deploying monitoring stack..." -ForegroundColor Yellow
helm install monitoring-stack . -n monitoring --create-namespace -f values-local-fixed.yaml
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Monitoring deployment failed" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Monitoring deployed" -ForegroundColor Green

# Wait for pods to be ready
Write-Host "Waiting for pods to be ready (this may take 2-5 minutes)..." -ForegroundColor Yellow
kubectl get pods -n wordpress
kubectl wait --for=condition=ready pod -l app=wordpress -n wordpress --timeout=300s
kubectl wait --for=condition=ready pod -l app=mysql -n wordpress --timeout=300s
kubectl wait --for=condition=ready pod -l app=nginx -n wordpress --timeout=300s
kubectl get pods -n monitoring
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=300s

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Status:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Show URLs
Write-Host "🌐 Application URLs:" -ForegroundColor Yellow
Write-Host "  • WordPress:      http://localhost:30080" -ForegroundColor White
Write-Host "  • Prometheus:     http://localhost:30090" -ForegroundColor White
Write-Host "  • Grafana:        http://localhost:30300 (admin/admin123)" -ForegroundColor White
Write-Host "  • Your Dashboard: http://localhost:5173 (after starting frontend)" -ForegroundColor White

Write-Host "🎉 Deployment completed!" -ForegroundColor Green

# Access information for services
$nginxNodePort = (kubectl get svc nginx -n wordpress -o jsonpath='{.spec.ports[0].nodePort}' 2>$null)
if ($nginxNodePort) {
    Write-Host "WordPress: http://localhost:$nginxNodePort" -ForegroundColor Yellow
} else {
    Write-Host "WordPress: Use port-forward (see below)" -ForegroundColor Yellow
}

$grafanaNodePort = (kubectl get svc grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}' 2>$null)
if ($grafanaNodePort) {
    Write-Host "Grafana:   http://localhost:$grafanaNodePort (admin/admin123)" -ForegroundColor Yellow
} else {
    Write-Host "Grafana:   Use port-forward (see below)" -ForegroundColor Yellow
}

$prometheusNodePort = (kubectl get svc prometheus -n monitoring -o jsonpath='{.spec.ports[0].nodePort}' 2>$null)
if ($prometheusNodePort) {
    Write-Host "Prometheus: http://localhost:$prometheusNodePort" -ForegroundColor Yellow
}

Write-Host "Or use port-forward:" -ForegroundColor Cyan
Write-Host "  kubectl port-forward -n wordpress svc/nginx 8080:80" -ForegroundColor White
Write-Host "  kubectl port-forward -n monitoring svc/grafana 3000:3000" -ForegroundColor White
Write-Host "  kubectl port-forward -n monitoring svc/prometheus 9090:9090" -ForegroundColor White

Write-Host "To uninstall:" -ForegroundColor Cyan
Write-Host "  helm uninstall wordpress-app -n wordpress" -ForegroundColor White
Write-Host "  helm uninstall monitoring -n monitoring" -ForegroundColor White
Write-Host "  kubectl delete namespace wordpress monitoring" -ForegroundColor White

Write-Host "Happy testing! 🚀" -ForegroundColor Green
