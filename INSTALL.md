# Installation Guide

## Overview

The platform installs in four sequential steps using standalone Python scripts.
Everything environment-specific (IP addresses, passwords, SSH keys, TLS certificates)
is generated or auto-detected at install time — nothing is hardcoded.

## Requirements

| Item | Requirement |
|---|---|
| OS | Ubuntu 24.04 LTS (fresh install recommended) |
| CPU | 8+ cores (nested virtualisation required for Windows detonation) |
| RAM | 32 GB (16 GB minimum without detonation) |
| Disk | 500 GB+ |
| Nested virt | VMware: `vhv.enable = TRUE`; KVM: `cpu host` |
| Python | 3.10+ (system Python, no venv needed) |
| Network | Static IP recommended; internet access during install |

### Verify nested virtualisation

```bash
grep -c vmx /proc/cpuinfo   # should return > 0
```

For VMware guests, add to the `.vmx` file **before** starting the VM:
```
vhv.enable = "TRUE"
```

---

## Step 0 — Prerequisites

Installs: `containerd`, `nerdctl`, `buildkit`, CNI plugins,
`kubeadm`/`kubelet`/`kubectl`, `nginx`, `iptables-persistent`.

```bash
sudo python3 install_00_prereqs.py
```

Options:
```
--skip-k8s        Skip Kubernetes tool installation (already installed)
--skip-kubevirt   Skip KubeVirt (no Windows detonation needed)
```

---

## Step 1 — Kubernetes Cluster

Initialises a single-node cluster with Calico eBPF CNI and KubeVirt.

```bash
sudo python3 install_01_cluster.py
```

Options:
```
--kubeconfig PATH   Where to write admin.conf (default: /etc/kubernetes/admin.conf)
--pod-cidr CIDR     Pod network CIDR (default: 10.244.0.0/16)
--skip-kubevirt     Skip KubeVirt + CDI installation
```

After completion, verify:
```bash
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl get nodes   # should show STATUS=Ready
```

---

## Step 2 — Platform Deployment

The main deployment step. Generates all secrets, builds images, configures nginx.

```bash
sudo python3 install_02_platform.py \
    --repo-dir /opt/secops-platform \
    --host-ip AUTO \
    --hostname secops-platform \
    --lan-cidr 192.168.1.0/24
```

Required arguments:
```
--repo-dir PATH     Path to this repository
```

Optional arguments:
```
--host-ip IP        Host IP for TLS SANs and URLs (default: AUTO-detect)
--hostname NAME     Hostname for TLS certificate CN (default: secops-platform)
--lan-cidr CIDR     Your LAN subnet for NetworkPolicy ingress rules
                    (e.g. 192.168.1.0/24 — lets analysts reach the portal)
--admin-user USER   OS username for systemd service (default: $SUDO_USER)
--skip-build        Skip container image builds (if already built)
```

### What this does

1. **Generates fresh secrets** — unique passwords for MinIO, PostgreSQL, Grafana;
   session secret and admin secret for the portal. Saved to `generated_credentials.txt`.
2. **Generates SSH key pair** — ED25519 key for analyst jump host access.
   Private key saved to `generated_keys/analyst_ed25519`.
3. **Generates TLS certificate** — self-signed RSA-4096, 10-year validity,
   SANs include the host IP and hostname.
4. **Configures nginx** — TLS termination, security headers, rate limiting.
5. **Applies Kubernetes manifests** — namespaces, RBAC, all deployments.
6. **Builds container images** — all platform images via nerdctl/buildkit.
7. **Creates detonation ConfigMap** — `detonate.ps1` + `sysmonconfig.xml`.
8. **Initialises PostgreSQL schema** — all tables.
9. **Configures firewall** — auto-detects primary interface, opens required ports.
10. **Creates systemd service** — `secops-platform.service` for auto-start on boot.

### Generated files

After step 2:
```
generated_credentials.txt    All passwords (chmod 600) — note and delete
generated_keys/
  analyst_ed25519            SSH private key for jump host
  analyst_ed25519.pub        SSH public key (loaded into Kubernetes Secret)
```

> **Security note:** `generated_credentials.txt` contains all platform passwords
> in plaintext. Note them in a password manager and delete the file.

---

## Step 3 — CTF Engine

Deploys challenge pods, initialises DVWA, and runs health checks.

```bash
python3 install_03_ctf.py \
    --repo-dir /opt/secops-platform \
    --host-ip AUTO
```

Options:
```
--host-ip IP          Host IP (default: AUTO-detect)
--flag-sqli FLAG      Customise the SQL injection flag
                      (default: flag{sql_1nj3ct10n_4_th3_w1n})
```

This generates `start_platform.sh` — a full platform start script with the
host IP baked in. The systemd service created in step 2 uses this script.

---

## Post-Installation

### First login

1. Open `https://<host-ip>/` in a browser
2. Accept or bypass the TLS warning (or install the CA cert — see below)
3. Register an analyst account
4. Log in as `admin` — you will be prompted to set a password on first login

### Install the CA certificate (recommended)

Installs the self-signed cert as a trusted root, enabling PCAP uploads from Chrome.

**Windows:**
1. Download `http://<host-ip>/portal-ca.crt`
2. Double-click → Install Certificate → Local Machine
3. Place in: Trusted Root Certification Authorities
4. Restart Chrome

**Linux/Mac:**
```bash
# Linux
sudo cp portal-ca.crt /usr/local/share/ca-certificates/secops-platform.crt
sudo update-ca-certificates

# Mac
sudo security add-trusted-cert -d -r trustRoot \
    -k /Library/Keychains/System.keychain portal-ca.crt
```

### SSH jump host access

```bash
ssh -i generated_keys/analyst_ed25519 -p 2022 analyst@<host-ip>
```

### Windows detonation VM

The detonation pipeline requires a Windows 10 base disk image.
See [docs/windows-vm-setup.md](docs/windows-vm-setup.md) for preparation instructions.

---

## Customising Flags

All CTF flags are set in challenge source files. Edit before running step 3:

| Challenge | File | Location |
|---|---|---|
| SSH pivot | `ctf/challenges/pivot/Containerfile` | `chpasswd` and `root_flag.txt` |
| Registry | `ctf/challenges/registry/setup.sh` | `AuthToken` registry value |
| PCAP/Network | Replace `ctf/challenges/pcap/hashcap.pcap` | PCAP credential in traffic |
| SQL injection | `--flag-sqli` argument to `install_03_ctf.py` | DVWA user password |

See [docs/flags.md](docs/flags.md) for full flag documentation.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| NodePorts not responding after reboot | kube-proxy NAT rules not synced | `kubectl rollout restart daemonset kube-proxy -n kube-system` |
| Portal returns 502 Bad Gateway | Portal pod not ready | `kubectl get pods -n analyst` — wait for Running |
| `nerdctl rmi` fails (image in use) | Stopped containers reference image | `sudo nerdctl --namespace k8s.io container prune -f` then retry |
| Detonation job stuck >15 min | detonate.ps1 not executing on VM | Check sidecar logs; verify VM booted; mark job as error in DB |
| Analysis pod OOMKilled | radare2/capa on large binary | Expected — size-gated at 20/30 MB; job reports note skip |
| Chrome blocks PCAP upload | Self-signed cert not trusted | Install `portal-ca.crt` as Trusted Root CA on client |
| `kubectl` not found after reboot | PATH not set | `export KUBECONFIG=/etc/kubernetes/admin.conf` |
| Stale analysis namespaces | Cleanup job failed | `kubectl get ns \| grep ^analysis- \| awk '{print $1}' \| xargs kubectl delete ns` |

### Useful diagnostic commands

```bash
# Platform health
kubectl get pods --all-namespaces
kubectl get nodes

# Portal logs
kubectl logs -n analyst -l app=analyst-portal --tail=50

# Force job cleanup
kubectl exec -n analyst <postgres-pod> -- psql -U analyst -d analyst -c \
  "UPDATE jobs SET status='error', completed_at=NOW() WHERE status='running' AND started_at < NOW() - INTERVAL '1 hour';"

# Restart nginx
sudo nginx -t && sudo nginx -s reload
```
