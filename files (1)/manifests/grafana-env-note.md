# Grafana Manifest Note

The `analysis/manifests/logging/grafana.yaml` manifest contains a
`GF_SERVER_ROOT_URL` environment variable that must be set to your host IP or
hostname. The installer patches this automatically.

If editing manually, update this value:

```yaml
- name: GF_SERVER_ROOT_URL
  value: "https://YOUR_HOST_IP_OR_HOSTNAME/grafana"
```

The installer handles this via `install_02_platform.py --host-ip`.
