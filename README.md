# Assignment-Syfe

Production-grade WordPress on Kubernetes with Nginx (OpenResty), MySQL, Redis, Prometheus, and Grafana. Optimized for local development on Windows (Docker Desktop with Kubernetes), with simple Helm charts and NodePort access.

- WordPress (local): http://localhost:30080
- Prometheus: http://localhost:30090
- Grafana: http://localhost:30300 (admin / admin123)
 - Metrics Catalog: [METRICS_CATALOG.md](./METRICS_CATALOG.md)

## Folder structure

```
.
├─ build-images.ps1                  # Build custom Docker images (Windows PowerShell)
├─ deploy-local.ps1                  # One-shot local deploy of app + monitoring
├─ start-monitoring.ps1              # Optional: waits/port-forwards for monitoring
├─ troubleshoot-wordpress.ps1        # Handy cleanup and debug commands
├─ docker-compose.yml                # Not required for k8s (kept for reference)
├─ METRICS_CATALOG.md                # Full metrics spec (queries, dashboards, alerts)
├─ README.md                         # This file
└─ backend
  ├─ dockerfiles
  │  ├─ nginx/                      # OpenResty + Lua Prometheus metrics
  │  ├─ mysql/                      # MySQL 8 base + config
  │  └─ wordpress/                  # php-fpm based WordPress image
  └─ helm
    ├─ wordpress-app/              # Helm chart: WordPress + Nginx + MySQL + Redis
    │  ├─ values-local-fixed.yaml  # Local-friendly values (NodePort, hostpath)
    │  └─ templates/               # Deployments, Services, PVCs, etc.
    └─ monitoring-stack/           # Helm chart: Prometheus + Grafana
      ├─ values-local-fixed.yaml  # Local-friendly values (NodePort, hostpath)
      └─ templates/               # Prom config, rules, Grafana provisioning
```

## Tech stack

- Kubernetes + Helm (simple, self-contained charts)
- Docker (custom images for Nginx/OpenResty, WordPress php-fpm, MySQL)
- Nginx (OpenResty) with Lua Prometheus metrics endpoint
- WordPress (php-fpm) + PHP‑FPM exporter sidecar
- MySQL 8 + mysqld-exporter
- Redis (optional caching for WP)
- Prometheus + Grafana (NodePort for easy local access)

## Helm charts at a glance

1) `backend/helm/wordpress-app`
  - Components: Nginx (reverse proxy), WordPress (php-fpm), MySQL (StatefulSet), Redis
  - Storage: hostpath PVCs for Docker Desktop
  - Access: Nginx Service is NodePort 30080
  - Probes: tcpSocket for php-fpm and MySQL; Nginx `/health` HTTP probe
  - Metrics: Nginx exposes `/metrics` (port 9145), WordPress pods annotated for PHP‑FPM exporter (port 9253)

2) `backend/helm/monitoring-stack`
  - Prometheus (NodePort 30090) + optional Grafana (NodePort 30300)
  - PVCs: hostpath, small sizes for local
  - Scrape jobs included for Nginx, WP pods (php‑fpm), MySQL exporter
  - Pre-configured rules examples; dashboards are provisioned/gated by values

Tip: Local value files `values-local-fixed.yaml` set NodePorts and persistence suited to Docker Desktop.

## Prerequisites (Windows local)

- Docker Desktop with Kubernetes enabled
- kubectl and helm available on PATH

Verify quickly:
```powershell
kubectl version --client --short
helm version --short
kubectl cluster-info
kubectl get storageclass
```

## Quick start (local)

Build images and deploy (recommended):
```powershell
./build-images.ps1
./deploy-local.ps1
```

After deploy, wait ~1–3 minutes and open:
- WordPress: http://localhost:30080
- Prometheus: http://localhost:30090
- Grafana: http://localhost:30300 (admin/admin123)

If you only want to (re)start monitoring services:
```powershell
./start-monitoring.ps1
```

## How to use Grafana

1) Login at http://localhost:30300 → admin/admin123
2) Data source: Prometheus
  - URL inside cluster: `http://prometheus.monitoring.svc:9090`
  - Or local NodePort: `http://localhost:30090`
3) Import useful dashboards by ID:
  - Nginx: 12708 or 9614
  - PHP‑FPM: 11019 or 12162
  - MySQL: 7362 or 14057
4) Or create panels using queries in [METRICS_CATALOG.md](./METRICS_CATALOG.md).

## Metrics you get out-of-the-box

- Nginx: requests, latency histogram, active connections (Lua prometheus)
- WordPress PHP‑FPM: active/idle processes, queue length, accepted connections
- MySQL: connections, QPS, slow queries (mysqld-exporter)
- Kubernetes: core pod/node metrics (plus optional node-exporter, kube-state-metrics)

See full list and PromQL in [METRICS_CATALOG.md](./METRICS_CATALOG.md).

## Troubleshooting

- Stuck PVCs (Terminating): scale deployments to 0, delete/recreate PVCs, then re-apply helm
- MySQL auth/init issues: delete the MySQL pod to re-init from PVC or reset the PVC if needed
- NodePort in use: adjust the NodePort in `values-local-fixed.yaml` and upgrade the release

## Clean uninstall

```powershell
helm uninstall wordpress-app -n wordpress
helm uninstall monitoring -n monitoring
kubectl delete namespace wordpress,monitoring
```