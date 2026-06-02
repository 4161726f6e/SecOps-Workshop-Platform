# CTF Flag Configuration

All flags are set before deployment. The defaults shown here are for reference only
— change them before running the install scripts.

## Flag Locations

### SSH Pivot — two flags

**File:** `ctf/challenges/pivot/Containerfile`

```dockerfile
# Player user password (flag 1 — obtained after SSH access)
RUN echo "player:YOUR_PIVOT_FLAG_1_HERE" | chpasswd

# Root flag (flag 2 — obtained after privilege escalation)
RUN echo "YOUR_PIVOT_FLAG_2_HERE" > /root/root_flag.txt
```

### Registry Forensics

**File:** `ctf/challenges/registry/setup.sh`

```bash
# Registry value containing the flag
"AuthToken"="YOUR_REGISTRY_FLAG_HERE"
```

### PCAP / Network Forensics

The flag is embedded in the PCAP file as a cleartext credential.
Replace `ctf/challenges/pcap/hashcap.pcap` with your own PCAP.

The PCAP should contain an authentication exchange where the password
(or a hash of it) is the flag. The challenge description should indicate
what protocol and what to look for.

> **Note:** Do not commit PCAP files to the repository — they are excluded
> by `.gitignore`. Distribute PCAP files separately or generate them as
> part of your deployment process.

### SQL Injection

The SQLi flag is set as the DVWA `ctfadmin` user's password (MD5 hashed).

Set it via the install script:

```bash
python3 install_03_ctf.py \
    --repo-dir /opt/secops-platform \
    --flag-sqli "YOUR_SQLI_FLAG_HERE"
```

Or update it manually after deployment:

```bash
FLAG="YOUR_SQLI_FLAG_HERE"
HASH=$(python3 -c "import hashlib; print(hashlib.md5('$FLAG'.encode()).hexdigest())")
DVWA_POD=$(kubectl get pods -n ctf -l app=webvuln -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n ctf $DVWA_POD -- php -r "
\$db = new mysqli('127.0.0.1', 'app', 'vulnerables', 'dvwa');
\$db->query(\"UPDATE users SET password='$HASH' WHERE user='ctfadmin'\");
echo 'Updated';
"
```

## Rebuilding Challenges After Flag Changes

After editing flag values in Containerfiles, rebuild the affected images:

```bash
# Rebuild pivot challenge
sudo nerdctl --namespace k8s.io rmi ctf-pivot:latest
sudo nerdctl --namespace k8s.io build --no-cache \
    -t ctf-pivot:latest ctf/challenges/pivot/

# Rebuild registry challenge
sudo nerdctl --namespace k8s.io rmi ctf-registry:latest
sudo nerdctl --namespace k8s.io build --no-cache \
    -t ctf-registry:latest ctf/challenges/registry/

# Restart affected pods
kubectl rollout restart deployment -n ctf
```
