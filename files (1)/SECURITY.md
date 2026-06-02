# Security Policy

## Security Model

This platform is designed for **internal use in controlled training environments**.
It is not intended to be exposed to the public internet.

### What the platform provides

- TLS on all analyst-facing endpoints (self-signed by default)
- bcrypt password hashing (cost 12) for all user accounts
- Signed session tokens (itsdangerous TimestampSigner, 7-day expiry)
- Rate limiting on authentication endpoints (10 req/min)
- Six HTTP security headers on all HTTPS responses
- Kubernetes NetworkPolicies with default-deny-all in all namespaces
- Analysis jobs run in isolated ephemeral namespaces (deleted after completion)
- All secrets generated fresh at install time — never hardcoded

### Known accepted risks

| Risk | Reason accepted |
|---|---|
| Self-signed TLS certificate | Internal use; CA cert installable on clients |
| MinIO plain HTTP internally | Cluster-internal only; no external exposure |
| Loki has no authentication | Cluster-internal only; network policy restricted |
| Jump host `allowPrivilegeEscalation` | Required for sshd operation |
| No upload file type validation | Intentional — malware analysis requires arbitrary files |
| Broad analyst-platform ClusterRole | Required for namespace + VM lifecycle management |

### Deployment guidance

- Deploy behind a firewall; restrict access to trusted analyst networks
- The `--lan-cidr` flag in `install_02_platform.py` sets the NetworkPolicy
  ingress CIDR — use the narrowest range that covers your analyst workstations
- The generated `portal-ca.crt` should be distributed to analyst machines only
- Rotate credentials periodically using `kubectl edit secret platform-credentials -n analyst`
- Do not expose NodePorts (31xxx) directly; all analyst access should go through nginx on port 443

---

## Responsible Disclosure

If you discover a security vulnerability in this platform:

1. **Do not open a public GitHub issue** for security vulnerabilities
2. Email the maintainers at the address in the repository's GitHub profile, or
   use [GitHub's private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing/privately-reporting-a-security-vulnerability)
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if known)

We aim to respond within 5 business days and will coordinate a disclosure timeline with you.

### Scope

In scope:
- Authentication and authorisation bypass
- Secret or credential exposure
- Container escape from analysis jobs
- Remote code execution via the portal
- Privilege escalation within the cluster

Out of scope:
- Vulnerabilities in deliberately vulnerable CTF challenges (DVWA, etc.)
- Issues requiring physical access to the host
- Denial of service attacks
- Known accepted risks listed above

---

## CTF Challenge Security

The CTF challenges contain intentionally vulnerable software (DVWA, vulnerable SSH
configurations, etc.). These are isolated in the `ctf` namespace with NetworkPolicies
that prevent lateral movement to the analyst platform or host.

**Do not deploy CTF challenges with public internet exposure** — they contain
deliberately exploitable vulnerabilities.
