# Build All Docker Images for Syfe WordPress Application
# Run this script to build all required custom Docker images

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Building Syfe WordPress Docker Images" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"

# Check if Docker is running
try {
    docker version | Out-Null
    Write-Host "✅ Docker is running" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker is not running or not installed!" -ForegroundColor Red
    Write-Host "Please start Docker Desktop and try again." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Building images..." -ForegroundColor Yellow
Write-Host ""

# Build Nginx (OpenResty) image
Write-Host "1. Building Nginx (OpenResty) image..." -ForegroundColor Cyan
cd backend/dockerfiles/nginx
docker build -t syfe-nginx:latest .
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Nginx image built successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to build Nginx image" -ForegroundColor Red
    exit 1
}
cd ../../..
Write-Host ""

# Build MySQL image
Write-Host "2. Building MySQL image..." -ForegroundColor Cyan
cd backend/dockerfiles/mysql
docker build -t syfe-mysql:latest .
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ MySQL image built successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to build MySQL image" -ForegroundColor Red
    exit 1
}
cd ../../..
Write-Host ""

# Build WordPress image
Write-Host "3. Building WordPress image..." -ForegroundColor Cyan
cd backend/dockerfiles/wordpress
docker build -t syfe-wordpress:latest .
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ WordPress image built successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to build WordPress image" -ForegroundColor Red
    exit 1
}
cd ../../..
Write-Host ""

# Verify all images
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verifying Built Images:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$images = @("syfe-nginx:latest", "syfe-mysql:latest", "syfe-wordpress:latest")
foreach ($image in $images) {
    $exists = docker images -q $image
    if ($exists) {
        $size = docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | Select-String $image
        Write-Host "✅ $image - $($size.ToString().Split("`t")[1])" -ForegroundColor Green
    } else {
        Write-Host "❌ $image - NOT FOUND" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ All Docker images built successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Deploy WordPress app:" -ForegroundColor White
Write-Host "   helm install wordpress-app backend/helm/wordpress-app -n wordpress --create-namespace -f backend/helm/wordpress-app/values-local-fixed.yaml" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Deploy monitoring stack:" -ForegroundColor White
Write-Host "   helm install monitoring-stack backend/helm/monitoring-stack -n monitoring --create-namespace -f backend/helm/monitoring-stack/values-local-fixed.yaml" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Check deployment:" -ForegroundColor White
Write-Host "   kubectl get pods --all-namespaces" -ForegroundColor Gray
Write-Host ""