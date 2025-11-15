# Syfe Monitoring - Quick Access Script
# This script opens all monitoring dashboards

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Syfe Monitoring - Quick Access" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Starting port-forwarding for all monitoring services..." -ForegroundColor Yellow
Write-Host ""

# Check if monitoring namespace exists
$monitoringNs = kubectl get namespace monitoring --ignore-not-found -o name
if (-not $monitoringNs) {
    Write-Host "⚠️  Monitoring namespace not found!" -ForegroundColor Red
    Write-Host "Deploying monitoring stack..." -ForegroundColor Yellow
    cd backend\helm\monitoring-stack
    helm install monitoring-stack . -n monitoring --create-namespace -f values-local-fixed.yaml
    cd ..\..\..
    Write-Host "✅ Monitoring stack deployed. Waiting for pods to be ready..." -ForegroundColor Green
    kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=300s
    kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=300s
}

# Start port-forwarding in background
Write-Host "Starting port-forwards..." -ForegroundColor Yellow

# Prometheus
Start-Job -Name "Prometheus" -ScriptBlock {
    kubectl port-forward -n monitoring svc/prometheus 9090:9090
} | Out-Null
Write-Host "✅ Prometheus: http://localhost:9090" -ForegroundColor Green

# Grafana
Start-Job -Name "Grafana" -ScriptBlock {
    kubectl port-forward -n monitoring svc/grafana 3000:3000
} | Out-Null
Write-Host "✅ Grafana: http://localhost:3000 (admin/admin123)" -ForegroundColor Green

# Nginx (WordPress)
Start-Job -Name "Nginx" -ScriptBlock {
    kubectl port-forward -n wordpress svc/nginx 8080:80
} | Out-Null
Write-Host "✅ WordPress: http://localhost:8080" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  All Services Running!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "📊 Monitoring Dashboards:" -ForegroundColor Yellow
Write-Host "  • Your React Dashboard:  http://localhost:5173" -ForegroundColor White
Write-Host "  • Prometheus:           http://localhost:9090" -ForegroundColor White
Write-Host "  • Grafana:              http://localhost:3000" -ForegroundColor White
Write-Host "  • WordPress:            http://localhost:8080" -ForegroundColor White
Write-Host ""

Write-Host "🔍 What to Monitor:" -ForegroundColor Yellow
Write-Host "  1. Pod CPU Utilization (Prometheus query: rate(container_cpu_usage_seconds_total[5m]))" -ForegroundColor Gray
Write-Host "  2. Nginx Request Count (nginx_http_requests_total)" -ForegroundColor Gray
Write-Host "  3. Nginx 5xx Errors    (nginx_http_requests_total{status=~'5..'})" -ForegroundColor Gray
Write-Host ""

Write-Host "📈 Quick Prometheus Queries:" -ForegroundColor Yellow
Write-Host "  Go to http://localhost:9090/graph and try:" -ForegroundColor Gray
Write-Host "  • rate(nginx_http_requests_total[5m])" -ForegroundColor Cyan
Write-Host "  • rate(container_cpu_usage_seconds_total{namespace='wordpress'}[5m]) * 100" -ForegroundColor Cyan
Write-Host "  • kube_pod_container_status_restarts_total{namespace='wordpress'}" -ForegroundColor Cyan
Write-Host ""

Write-Host "🚨 Check Alerts:" -ForegroundColor Yellow
Write-Host "  • http://localhost:9090/alerts" -ForegroundColor White
Write-Host ""

Write-Host "📝 Check Detailed Guide:" -ForegroundColor Yellow
Write-Host "  • See MONITORING_GUIDE.md for complete instructions" -ForegroundColor White
Write-Host ""

Write-Host "⚠️  To stop all port-forwards, run:" -ForegroundColor Red
Write-Host "  Get-Job | Stop-Job; Get-Job | Remove-Job" -ForegroundColor Gray
Write-Host ""

Write-Host "Press Ctrl+C to exit (port-forwards will continue in background)" -ForegroundColor Yellow
Write-Host ""

# Show running jobs
Write-Host "Active port-forwards:" -ForegroundColor Cyan
Get-Job | Format-Table -AutoSize

# Keep script running
Write-Host ""
Write-Host "Port-forwards are running in background jobs." -ForegroundColor Green
Write-Host "You can close this window and they will continue." -ForegroundColor Green
Write-Host ""

# Optional: Open browsers automatically
$openBrowsers = Read-Host "Open all dashboards in browser? (y/n)"
if ($openBrowsers -eq 'y') {
    Start-Process "http://localhost:5173"
    Start-Sleep -Seconds 2
    Start-Process "http://localhost:9090"
    Start-Sleep -Seconds 2
    Start-Process "http://localhost:3000"
    Start-Sleep -Seconds 2
    Start-Process "http://localhost:8080"
    Write-Host "✅ All dashboards opened!" -ForegroundColor Green
}
