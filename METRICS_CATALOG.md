# Metrics Catalog: WordPress, Apache, Nginx, and Kubernetes

This document defines the required metrics to monitor a WordPress application, its web server (Nginx or Apache), and the underlying Kubernetes cluster, with Prometheus as the time-series database and Grafana for visualization.

Use this as your single source of truth for what to collect, how to scrape it, what to graph, and baseline alert thresholds.

## Architecture (what’s in this repo)

- Prometheus + Grafana on Kubernetes (NodePorts exposed locally)
- WordPress (php-fpm) + Nginx reverse proxy
- MySQL database
- Exporters / sources
  - Nginx Lua Prometheus endpoint (port 9145)
  - PHP‑FPM exporter sidecar for WordPress (port 9253)
  - mysqld-exporter for MySQL (port 9104)
  - node-exporter and kube-state-metrics for cluster-wide signals



---

## WordPress metrics

We track runtime via PHP‑FPM and add app-level metrics via plugins.

### PHP‑FPM (via `hipages/php-fpm_exporter`)
- Enable FPM status page: `pm.status_path=/status` (already configured)
- Exporter scrapes php-fpm and exposes on :9253.

Key metrics and queries:
- php_fpm_up — exporter health (should be 1)
- php_fpm_active_processes — real-time concurrency
- php_fpm_idle_processes — capacity buffer
- php_fpm_accepted_connections — request throughput counter
  - RPS: `rate(php_fpm_accepted_connections[5m])`
- php_fpm_listen_queue — backlog (watch for >0)
- php_fpm_slow_requests — slow-request counter (ideally 0)

SLO and suggested alerts:
- Backlog > 0 for 5m: `max_over_time(php_fpm_listen_queue[5m]) > 0`
- Slow requests > 0 for 5m: `increase(php_fpm_slow_requests[5m]) > 0`
- Active processes > 80% of max_children for 10m (requires knowing your pool size)

### Application-level
- WordPress plugin emitting metrics (e.g., via StatsD/Pushgateway) for:
  - wp_logins_total
  - wp_cache_hits_total / wp_cache_misses_total
  - wp_db_queries_total and latency histograms
  - wp_errors_total by type

These are optional and not required for infra health.

---

## Nginx metrics

We use OpenResty/Lua prometheus library to expose metrics under `/metrics` (port 9145). 

Standard metrics and queries:
- nginx_http_requests_total{status, method} — traffic and error rates
  - RPS: `sum(rate(nginx_http_requests_total[5m]))`
  - 5xx error rate: `sum(rate(nginx_http_requests_total{status=~"5.."}[5m])) / sum(rate(nginx_http_requests_total[5m]))`
- nginx_http_request_duration_seconds_bucket — latency histogram
  - p95 latency: `histogram_quantile(0.95, sum by (le) (rate(nginx_http_request_duration_seconds_bucket[5m])))`
- nginx_connections_active / reading / writing / waiting — concurrency snapshot

Custom per-route counter (optional but recommended):
- nginx_api_requests_total{route, method, status}
  - Per-route hits: `sum by (route) (rate(nginx_api_requests_total[5m]))`
  - Per-route 5xx: `sum by (route) (rate(nginx_api_requests_total{status=~"5.."}[5m]))`

Cardinality guidance:
- Normalize dynamic segments (IDs) to placeholders (e.g., `/api/items/:id`) before labeling `route` to avoid label explosion.

Suggested alerts:
- 5xx error rate > 5% for 10m
- p95 latency above budget (e.g., > 800ms for 10m)

---

## MySQL metrics (mysqld-exporter)

Key metrics and queries:
- mysql_up — exporter health
- mysql_global_status_threads_connected — current connections
- mysql_global_variables_max_connections — capacity
  - Utilization: `mysql_global_status_threads_connected / mysql_global_variables_max_connections`
- mysql_global_status_queries — total queries
  - QPS: `rate(mysql_global_status_queries[5m])`
- mysql_global_status_slow_queries — slow queries
  - Rate: `rate(mysql_global_status_slow_queries[5m])`

Alerts:
- Connection utilization > 80% for 15m
- Slow queries rate > baseline for 10m

---

## Kubernetes/Cluster metrics

Enable the following for a complete view:
- node-exporter — node CPU, memory, disk, network
- kube-state-metrics — Kubernetes object state (Deployments, Pods, PVCs, Nodes)
- cAdvisor (via Kubelet metrics) — container CPU/memory resource usage

Useful metrics and queries:
- Pod restarts: `rate(kube_pod_container_status_restarts_total[15m])`
- Pod readiness: `kube_pod_status_ready{condition="true"}`
- Deployment availability: `kube_deployment_status_replicas_available`
- CPU per pod (namespace=wordpress):
  - `sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="wordpress"}[5m]))`
- Memory per pod (namespace=wordpress):
  - `sum by (pod) (container_memory_working_set_bytes{namespace="wordpress"})`
- PVC capacity/usage (if exposed):
  - `kube_persistentvolume_capacity_bytes`, `kubelet_volume_stats_used_bytes`

Alerts:
- PodCrashLooping: restarts > 0 in 15m
- High CPU/memory utilization for pods or nodes
- PVC usage > 85%
- Deployment not meeting min available replicas

---

## Grafana: visualization plan

Data source
- Prometheus
  - URL inside cluster: `http://prometheus.monitoring.svc:9090`
  - Local NodePort: `http://localhost:30090`

Dashboards to import (by ID)
- Nginx: 12708 or 9614 (choose based on preference)
- PHP‑FPM: 11019 or 12162
- MySQL: 7362 or 14057
- Node Exporter Full: 1860 (if node-exporter enabled)
- Kubernetes / kube-state-metrics: 13332 or 8588

Minimal custom dashboard panels
- Traffic: `sum(rate(nginx_http_requests_total[5m]))`
- 5xx rate: `sum(rate(nginx_http_requests_total{status=~"5.."}[5m])) / sum(rate(nginx_http_requests_total[5m]))`
- p95 latency: `histogram_quantile(0.95, sum by (le) (rate(nginx_http_request_duration_seconds_bucket[5m])))`
- PHP‑FPM active/queue: `php_fpm_active_processes`, `php_fpm_listen_queue`
- DB connections: `mysql_global_status_threads_connected`
- Pod CPU/Memory (namespace=wordpress): see queries in previous section

---

## Prometheus scraping: jobs we rely on

- Nginx: Endpoints in namespace `wordpress`, service `nginx`, port `metrics` (9145)
- WordPress pods (php-fpm exporter): `prometheus.io/scrape=true`, `prometheus.io/port=9253`
- MySQL exporter: static target `mysql-exporter:9104`
- Optional: node-exporter and kube-state-metrics services

Scrape interval: 30s (local). Reduce for production cardinality; keep evaluation interval aligned.

Retention
- Local: 7d (Prometheus flag `--storage.tsdb.retention.time=7d`)
- Production: set based on storage budget and SLO analysis (e.g., 15–30d).

---

## Alerting rules (examples)

Nginx 5xx error rate high (5% for 10m)
```
(sum(rate(nginx_http_requests_total{status=~"5.."}[5m])) / sum(rate(nginx_http_requests_total[5m]))) * 100 > 5
```

PHP‑FPM backlog
```
max_over_time(php_fpm_listen_queue[5m]) > 0
```

MySQL connection usage
```
(mysql_global_status_threads_connected / mysql_global_variables_max_connections) * 100 > 80
```

Pod crash-looping
```
rate(kube_pod_container_status_restarts_total{namespace="wordpress"}[15m]) > 0
```

PVC almost full (example threshold)
```
(kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) * 100 > 85
```

---

## Best practices

- Labels & cardinality
  - Normalize path labels (e.g., `/api/items/:id`) to avoid unbounded label values.
  - Limit number of high-cardinality label dimensions.
- Sizing & retention
  - Keep scrape intervals reasonable (15–60s). Tune to SLOs and storage budget.
  - Use shorter retention for local/dev (7d) and larger for prod.
- Reliability
  - Use readiness/liveness probes that match real behavior (php-fpm TCP, Nginx /health).
  - Keep dashboards and alert rules in git (provisioned via ConfigMaps in this repo).
- Security
  - Restrict access to Prometheus/Grafana in production (authn/z, network policies).
  - Avoid sensitive data in labels or logs.
- Documentation
  - Keep this catalog in sync with chart changes (exporters, jobs, dashboards).
  - Add runbooks for common alerts (What happened, What to check, How to mitigate).

---

## How to validate quickly (local)

- Prometheus Targets: http://localhost:30090/targets — all jobs should be UP.
- Grafana: http://localhost:30300 — import dashboards, confirm panels show data.
- Generate load to see changes:
  - PowerShell: `for ($i=0; $i -lt 200; $i++) { Invoke-WebRequest http://localhost:30080 -UseBasicParsing | Out-Null }`

---

## Appendix: Exporters quick reference

- Nginx (OpenResty/Lua)
  - Path: `/metrics` on port 9145
  - Metrics: requests_total, duration histogram, connections
- PHP‑FPM exporter
  - Env: `PHP_FPM_SCRAPE_URI=tcp://127.0.0.1:9000/status`
  - Port: 9253, annotations applied via Helm
- mysqld-exporter
  - Service: `mysql-exporter:9104`
- Apache (if used)
  - `apache_exporter` scraping mod_status (e.g., http://apache:80/server-status?auto)

