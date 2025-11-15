# WordPress Troubleshooting Script for Syfe Infrastructure
# Run this script to diagnose and fix the WordPress CrashLoopBackOff issue

Write-Host "=" -ForegroundColor Cyan
Write-Host "Syfe WordPress Troubleshooting Script" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check WordPress logs
Write-Host "Step 1: Checking WordPress Pod Logs..." -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Yellow
$wordpressPod = kubectl get pods -n wordpress -l app=wordpress -o jsonpath='{.items[0].metadata.name}'
Write-Host "WordPress Pod: $wordpressPod" -ForegroundColor Green
Write-Host ""
Write-Host "Recent logs:" -ForegroundColor Cyan
kubectl logs -n wordpress $wordpressPod --tail=30
Write-Host ""

# Step 2: Check MySQL status
Write-Host "Step 2: Checking MySQL Status..." -ForegroundColor Yellow
Write-Host "--------------------------------" -ForegroundColor Yellow
Write-Host "MySQL Pod Status:" -ForegroundColor Cyan
kubectl get pod -n wordpress mysql-0
Write-Host ""

Write-Host "Testing MySQL connectivity..." -ForegroundColor Cyan
$mysqlPing = kubectl exec -n wordpress mysql-0 -- mysqladmin ping -h localhost -pwordpress123 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ MySQL is responding to ping" -ForegroundColor Green
} else {
    Write-Host "❌ MySQL is not responding: $mysqlPing" -ForegroundColor Red
}
Write-Host ""

Write-Host "Checking MySQL databases..." -ForegroundColor Cyan
kubectl exec -n wordpress mysql-0 -- mysql -u root -pwordpress123 -e "SHOW DATABASES;" 2>&1
Write-Host ""

# Step 3: Check if WordPress database exists
Write-Host "Step 3: Verifying WordPress Database..." -ForegroundColor Yellow
Write-Host "--------------------------------------" -ForegroundColor Yellow
$dbCheck = kubectl exec -n wordpress mysql-0 -- mysql -u root -pwordpress123 -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='wordpress';" 2>&1
if ($dbCheck -match "wordpress") {
    Write-Host "✅ WordPress database exists" -ForegroundColor Green
} else {
    Write-Host "❌ WordPress database NOT found. Creating..." -ForegroundColor Red
    kubectl exec -n wordpress mysql-0 -- mysql -u root -pwordpress123 -e "CREATE DATABASE IF NOT EXISTS wordpress; GRANT ALL ON wordpress.* TO 'wordpress'@'%' IDENTIFIED BY 'wordpress123'; FLUSH PRIVILEGES;"
    Write-Host "✅ Database created and permissions granted" -ForegroundColor Green
}
Write-Host ""

# Step 4: Check PVC status
Write-Host "Step 4: Checking Persistent Volume Claims..." -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Yellow
kubectl get pvc -n wordpress
Write-Host ""

# Step 5: Check WordPress deployment configuration
Write-Host "Step 5: Checking WordPress Deployment Config..." -ForegroundColor Yellow
Write-Host "----------------------------------------------" -ForegroundColor Yellow
Write-Host "Environment variables:" -ForegroundColor Cyan
kubectl get deployment -n wordpress wordpress -o jsonpath='{.spec.template.spec.containers[0].env[*].name}' 2>&1
Write-Host ""
Write-Host ""

# Step 6: Check pod events
Write-Host "Step 6: Recent Pod Events..." -ForegroundColor Yellow
Write-Host "---------------------------" -ForegroundColor Yellow
kubectl describe pod -n wordpress $wordpressPod | Select-String -Pattern "Events:" -Context 0,20
Write-Host ""

# Step 7: Recommendations
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Recommendations:" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Based on the logs above, common fixes:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. If MySQL connection error:" -ForegroundColor White
Write-Host "   kubectl rollout restart deployment/wordpress -n wordpress" -ForegroundColor Gray
Write-Host ""
Write-Host "2. If permission error on /var/www/html:" -ForegroundColor White
Write-Host "   kubectl exec -n wordpress $wordpressPod -- chown -R www-data:www-data /var/www/html" -ForegroundColor Gray
Write-Host ""
Write-Host "3. If database initialization error:" -ForegroundColor White
Write-Host "   kubectl exec -n wordpress mysql-0 -- mysql -u root -pwordpress123 wordpress < backend/dockerfiles/mysql/init-wordpress.sql" -ForegroundColor Gray
Write-Host ""
Write-Host "4. To delete and recreate WordPress pod:" -ForegroundColor White
Write-Host "   kubectl delete pod -n wordpress $wordpressPod" -ForegroundColor Gray
Write-Host ""
Write-Host "5. To check real-time logs:" -ForegroundColor White
Write-Host "   kubectl logs -n wordpress $wordpressPod -f" -ForegroundColor Gray
Write-Host ""

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "After fixing, verify with:" -ForegroundColor Cyan
Write-Host "kubectl get pods -n wordpress" -ForegroundColor Gray
Write-Host ""
Write-Host "Then access WordPress:" -ForegroundColor Cyan
Write-Host "kubectl port-forward -n wordpress svc/nginx 8080:80" -ForegroundColor Gray
Write-Host "Open: http://localhost:8080" -ForegroundColor Gray
Write-Host "=====================================" -ForegroundColor Cyan
