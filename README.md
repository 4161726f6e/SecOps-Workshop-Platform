# SecOps Workshop Platform

A self-contained cybersecurity training platform combining a **CTF engine** with a **Windows malware analysis lab**, deployable on a single Linux host.

## What Is This?

This platform provides two integrated environments for security training:

### CTF Engine
Five hands-on challenges covering real-world attack techniques:
- **Web Application** — SQL injection (DVWA)
- **Registry Forensics** — Windows registry analysis
- **Network Forensics** — PCAP analysis and credential extraction
- **SSH Pivoting** — lateral movement and privilege escalation
- **Scoreboard** — CTFd with challenge tracking

### Malware Analysis Platform
A browser-accessible analysis lab with three analysis types:

| Analysis Type | Capability |
|---|---|
| **Static Binary** | PE metadata, entropy, imports, rich strings (URLs/IPs/registry/paths), YARA, CAPA, DIE compiler detection |
| **PCAP Analysis** | Suricata alerts, structured DNS/HTTP/TLS/NTLM, top talkers, IP classification, extracted file hashing |
| **Windows Detonation** | KubeVirt Windows 10 VM, Sysmon telemetry, multi-type execution (EXE/DLL/PS1/BAT/JS/VBS/HTA/ZIP), Security event log |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Ubuntu 24 Host                        │
│                                                         │
│  nginx (443/TLS) ──► Analyst Portal (FastAPI)           │
│                           │                             │
│              ┌────────────┼────────────┐                │
│              ▼            ▼            ▼                │
│           MinIO       PostgreSQL   Kubernetes Jobs       │
│         (artifacts)   (metadata)       │                │
│                                   ┌───┴───┐             │
│                              Static    KubeVirt         │
│                              Analysis  Windows VM       │
│                                         │               │
│                              Sysmon ◄──►│               │
│                              Loki/Grafana               │
└─────────────────────────────────────────────────────────┘
```

### Key Components

- **Kubernetes** (kubeadm v1.29, single-node, Calico eBPF)
- **KubeVirt + CDI** for Windows VM lifecycle management
- **MinIO** for artifact and report storage
- **PostgreSQL** for job and user metadata
- **Loki + Promtail + Grafana** for Sysmon and fake-internet telemetry
- **Fake-internet sinkhole** (DNS + HTTP + SMTP) for detonation traffic capture

## Requirements

| Item | Requirement |
|---|---|
| OS | Ubuntu 24.04 LTS |
| CPU | 8+ cores with nested virtualisation |
| RAM | 32 GB (16 GB without detonation) |
| Disk | 500 GB+ |
| Nested virt | VMware: `vhv.enable = TRUE` / KVM: `cpu host` |
| Python | 3.10+ |
| Network | Static IP, internet access during install |

## Installation

Installation is handled by four sequential Python scripts — no hardcoded hostnames, IPs, usernames, or passwords:

```bash
# 1. Install system prerequisites
sudo python3 install_00_prereqs.py

# 2. Initialise Kubernetes cluster + Calico + KubeVirt
sudo python3 install_01_cluster.py

# 3. Deploy the platform (generates all secrets, builds images, configures nginx)
sudo python3 install_02_platform.py \
    --repo-dir /opt/secops-platform \
    --host-ip AUTO \
    --lan-cidr 192.168.1.0/24

# 4. Deploy CTF challenges and run health checks
python3 install_03_ctf.py --repo-dir /opt/secops-platform
```

See [INSTALL.md](INSTALL.md) for full installation documentation.

## Security

- All secrets generated fresh at install time (never hardcoded)
- Portal protected by bcrypt passwords + signed session tokens
- Rate limiting on auth endpoints (10 req/min login/register)
- Six security headers on all HTTPS responses (HSTS, CSP, X-Frame-Options, etc.)
- Kubernetes NetworkPolicies with default-deny-all in all namespaces
- Analysis jobs run in isolated ephemeral namespaces

See [SECURITY.md](SECURITY.md) for the security model and responsible disclosure policy.

## Windows Detonation VM

The detonation pipeline requires a pre-built Windows 10 base disk. This is **not included** in the repository and must be prepared separately. See [docs/windows-vm-setup.md](docs/windows-vm-setup.md) for preparation instructions.

## Customising Flags

CTF flags are set during installation. To use your own flags:

```bash
# Edit challenge Containerfiles before building
vim ctf/challenges/pivot/Containerfile
vim ctf/challenges/registry/setup.sh

# Edit the SQLi flag passed to the CTF deployer
python3 install_03_ctf.py --repo-dir . --flag-sqli "flag{your_flag_here}"
```

See [docs/flags.md](docs/flags.md) for all flag locations.

## Directory Structure

```
.
├── install_00_prereqs.py      # Step 0: system prerequisites
├── install_01_cluster.py      # Step 1: Kubernetes cluster
├── install_02_platform.py     # Step 2: platform deployment
├── install_03_ctf.py          # Step 3: CTF engine
├── INSTALL.md                 # Full installation guide
├── SECURITY.md                # Security model + disclosure policy
├── analysis/
│   ├── intake-api/            # Analyst portal (FastAPI)
│   │   └── main.py
│   ├── images/
│   │   ├── static-binary/     # PE/ELF static analysis image
│   │   ├── static-pcap/       # PCAP analysis image (tshark + Suricata)
│   │   ├── detonation-sidecar/# VM coordination sidecar
│   │   ├── fake-internet/     # DNS/HTTP/SMTP sinkhole
│   │   ├── jump-host/         # SSH jump host
│   │   └── pool-controller/   # KubeVirt VM pool manager
│   └── manifests/             # Kubernetes manifests
│       ├── analyst-portal.yaml
│       ├── minio.yaml
│       ├── postgres.yaml
│       ├── jump-host.yaml
│       ├── namespace.yaml
│       ├── networkpolicy.yaml
│       ├── pool-controller.yaml
│       ├── fake-internet.yaml
│       └── logging/
│           ├── loki.yaml
│           ├── promtail.yaml
│           ├── grafana.yaml
│           └── grafana-dashboard.yaml
└── ctf/
    ├── manifests/             # CTF Kubernetes manifests
    └── challenges/
        ├── hashcap/           # Network forensics challenge
        ├── pcap/              # PCAP service
        ├── pivot/             # SSH pivot challenge
        ├── registry/          # Registry forensics challenge
        └── webvuln/           # Web application challenge (DVWA)
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT License — see [LICENSE](LICENSE).
