# Operations Guide

## Day-to-day administration

### Starting the platform

The `secops-platform.service` systemd unit starts everything automatically on boot.
To start manually:

```bash
bash /opt/secops-platform/start_platform.sh
```

### Health check

```bash
# All pods
kubectl get pods --all-namespaces

# Quick endpoint check
curl -sk -o /dev/null -w "Portal: %{http_code}\n" https://localhost/
curl -s -o /dev/null -w "MinIO: %{http_code}\n" http://localhost:31900/minio/health/live
curl -sk -o /dev/null -w "Grafana: %{http_code}\n" https://localhost/grafana/api/health
```

### User management

```bash
# List users
kubectl exec -n analyst <postgres-pod> -- psql -U analyst -d analyst -c \
  "SELECT username, role, active, created_at FROM users ORDER BY created_at;"

# Deactivate a user
curl -sk -b /tmp/admin_session.txt \
  -X POST https://localhost/admin/users/<username>/deactivate

# Force password reset
kubectl exec -n analyst <postgres-pod> -- psql -U analyst -d analyst -c \
  "UPDATE users SET force_password_change=TRUE WHERE username='<username>';"
```

### Credential rotation

```bash
NEW_MINIO_PASS=$(python3 -c "import secrets; print(secrets.token_urlsafe(24))")
NEW_PG_PASS=$(python3 -c "import secrets; print(secrets.token_urlsafe(24))")
NEW_SESSION=$(python3 -c "import secrets; print(secrets.token_hex(32))")
NEW_ADMIN=$(python3 -c "import secrets; print(secrets.token_hex(32))")
NEW_PG_DSN="postgresql://analyst:${NEW_PG_PASS}@postgres:5432/analyst"

kubectl patch secret platform-credentials -n analyst --type=merge -p \
  "{\"stringData\":{
    \"minio-password\":\"${NEW_MINIO_PASS}\",
    \"postgres-password\":\"${NEW_PG_PASS}\",
    \"postgres-dsn\":\"${NEW_PG_DSN}\",
    \"session-secret\":\"${NEW_SESSION}\",
    \"admin-secret\":\"${NEW_ADMIN}\"
  }}"

# Restart portal to pick up new secrets
kubectl rollout restart deployment analyst-portal -n analyst

# Update PostgreSQL password
kubectl exec -n analyst <postgres-pod> -- psql -U analyst -d analyst -c \
  "ALTER USER analyst PASSWORD '${NEW_PG_PASS}';"

# Update MinIO password (via mc or console at :31901)
```

### Cleaning up stale analysis jobs

```bash
# List stale namespaces
kubectl get ns | grep ^analysis-

# Delete all stale analysis namespaces
kubectl get ns | grep ^analysis- | awk '{print $1}' | xargs kubectl delete ns

# Mark stuck jobs as error
kubectl exec -n analyst <postgres-pod> -- psql -U analyst -d analyst -c \
  "UPDATE jobs SET status='error', completed_at=NOW(), error='manual cleanup'
   WHERE status='running' AND started_at < NOW() - INTERVAL '1 hour';"
```

### Rebuilding images

```bash
# Portal
kubectl scale deployment analyst-portal -n analyst --replicas=0
kubectl wait --for=delete pod -n analyst -l app=analyst-portal --timeout=30s
sudo nerdctl --namespace k8s.io rmi analyst-portal:latest
sudo nerdctl --namespace k8s.io build --no-cache -t analyst-portal:latest \
    /opt/secops-platform/analysis/intake-api/
kubectl scale deployment analyst-portal -n analyst --replicas=1

# Analysis images
sudo nerdctl --namespace k8s.io container prune -f
for img in ctf-static-pcap ctf-static-binary ctf-detonation-sidecar; do
    sudo nerdctl --namespace k8s.io rmi ${img}:latest 2>/dev/null || true
done
sudo nerdctl --namespace k8s.io build --no-cache -t ctf-static-pcap:latest \
    /opt/secops-platform/analysis/images/static-pcap/
sudo nerdctl --namespace k8s.io build --no-cache -t ctf-static-binary:latest \
    /opt/secops-platform/analysis/images/static-binary/
sudo nerdctl --namespace k8s.io build --no-cache -t ctf-detonation-sidecar:latest \
    /opt/secops-platform/analysis/images/detonation-sidecar/
```

### Updating detonation scripts

Changes to `detonate.ps1` or `sysmonconfig.xml` take effect on the next job —
no image rebuild needed:

```bash
kubectl create configmap detonation-scripts -n analyst \
    --from-file=detonate.ps1=/opt/secops-platform/analysis/images/detonation-sidecar/detonate.ps1 \
    --from-file=sysmonconfig.xml=/opt/secops-platform/analysis/images/detonation-sidecar/sysmonconfig.xml \
    --dry-run=client -o yaml | kubectl apply -f -
```

## Grafana dashboards

Access: `https://<host-ip>/grafana/` (credentials in `generated_credentials.txt`)

Pre-built dashboard covers:
- Sysmon event volume over time
- Top event IDs
- Process creation timeline per job
- Fake-internet DNS/HTTP requests
- Job completion rate

## Storage management

```bash
# MinIO usage
kubectl exec -n analyst <minio-pod> -- df -h /data

# PostgreSQL size
kubectl exec -n analyst <postgres-pod> -- psql -U analyst -d analyst -c \
  "SELECT pg_size_pretty(pg_database_size('analyst'));"

# Loki retention (default: no retention — configure in loki.yaml if needed)
du -sh /opt/analysis-data/loki/

# Clean up old reports from MinIO (retain last 30 days)
# Use mc (MinIO client) to set a lifecycle policy on the artifacts bucket
```
