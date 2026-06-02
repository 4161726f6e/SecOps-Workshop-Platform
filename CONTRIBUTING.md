# Contributing

Contributions are welcome. This document covers how to contribute effectively.

## Getting Started

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Test on a fresh Ubuntu 24 host using the install scripts
5. Submit a pull request

## Development Setup

For local development of the analyst portal or analysis images, you only need
a working Kubernetes cluster with the platform deployed. You don't need to
re-run the full install — just rebuild the specific component you're working on.

### Rebuild the portal

```bash
kubectl scale deployment analyst-portal -n analyst --replicas=0
kubectl wait --for=delete pod -n analyst -l app=analyst-portal --timeout=30s
sudo nerdctl --namespace k8s.io rmi analyst-portal:latest
sudo nerdctl --namespace k8s.io build --no-cache -t analyst-portal:latest analysis/intake-api/
kubectl scale deployment analyst-portal -n analyst --replicas=1
```

### Rebuild an analysis image

```bash
# Remove any stopped containers holding the old image
sudo nerdctl --namespace k8s.io container prune -f

sudo nerdctl --namespace k8s.io rmi ctf-static-pcap:latest
sudo nerdctl --namespace k8s.io build --no-cache \
    -t ctf-static-pcap:latest analysis/images/static-pcap/
```

### Update detonation scripts (no rebuild needed)

```bash
kubectl create configmap detonation-scripts -n analyst \
    --from-file=detonate.ps1=analysis/images/detonation-sidecar/detonate.ps1 \
    --from-file=sysmonconfig.xml=analysis/images/detonation-sidecar/sysmonconfig.xml \
    --dry-run=client -o yaml | kubectl apply -f -
```

---

## Areas for Contribution

### Analysis enrichment
- Add FLOSS (FireEye) for stack/decoded string extraction in static binary analysis
- Add JA3/JA4 TLS fingerprinting to PCAP analysis
- Add GeoIP enrichment for IP addresses
- Extend detonation to capture per-job PCAP (not just Sysmon)
- Add registry diff during detonation dwell period

### Platform features
- Multi-user job isolation improvements
- Artifact tagging and search
- Report export (PDF)
- Job comparison view (diff two reports)
- YARA rule management UI

### Infrastructure
- Multi-node cluster support
- Helm chart for platform deployment
- Support for non-VMware hypervisors for Windows VM
- Automated Windows base VM preparation script

### CTF challenges
- Additional challenge types (memory forensics, firmware analysis, etc.)
- Challenge difficulty tiers
- Automated scoring validation

---

## Code Style

### Python (portal, analysis images, install scripts)
- Follow PEP 8
- Type hints on function signatures
- Docstrings on public functions
- No hardcoded IPs, hostnames, usernames, or passwords anywhere

### PowerShell (detonate.ps1)
- Use `if/elseif` chains — avoid `switch` with scriptblock conditions
- Avoid function definitions (causes silent failures on some PS versions)
- Keep `$ErrorActionPreference = 'SilentlyContinue'` at top
- Log every significant step with `Write-EventLog`

### JavaScript (portal HTML)
- All JS is inline in the Python HTML strings
- No `//` comments (breaks single-line HTML embedding)
- No literal `\n` in JS strings inside Python triple-quoted strings
  (use `\\n` in Python source to produce `\n` in the served JS)
- Use backtick template literals for HTML generation — keep counts even

### Kubernetes manifests
- No hardcoded secrets or passwords — always use `secretKeyRef`
- Use `CIDR_PLACEHOLDER` for network ranges that vary by deployment
- Always specify resource requests and limits
- Use `imagePullPolicy: Never` for locally-built images

---

## Pull Request Guidelines

- One logical change per PR
- Include a description of what changed and why
- For new analysis capabilities: include a sample report showing the new output
- For security-related changes: reference the finding from SECURITY.md
- Update relevant documentation (INSTALL.md, README.md) if behaviour changes
- Do not include generated files (`generated_credentials.txt`, `generated_keys/`,
  built binaries, PCAP files with real traffic)

## Reporting Bugs

Open a GitHub issue with:
- OS and kernel version
- Platform version / git commit
- Steps to reproduce
- Expected vs actual behaviour
- Relevant pod logs (`kubectl logs -n analyst -l app=analyst-portal`)

For security vulnerabilities, see [SECURITY.md](SECURITY.md).
