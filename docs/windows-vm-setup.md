# Windows Base VM Setup

The detonation pipeline requires a Windows 10 VM disk pre-configured with
Sysmon, the detonation agent, and supporting tools. This disk is **not included**
in the repository and must be prepared manually.

## What the VM needs

| Component | Purpose |
|---|---|
| Windows 10 (any edition) | Base OS |
| Sysmon64.exe + config | Process/network/file telemetry |
| detonate.ps1 | Analysis agent (auto-downloaded from sidecar) |
| `C:\Tools\` directory | Working directory for agent |
| Scheduled task or registry run key | Auto-runs detonate.ps1 on boot |
| Sysmon configured to start automatically | Telemetry from boot |
| Windows Defender disabled or exclusion on `C:\Tools\` | Prevents sample blocking |
| Firewall rule allowing outbound to pod CIDR | Sidecar communication |

## Preparation steps

### 1. Create a Windows 10 VM with KubeVirt

```bash
# Create a DataVolume importing a Windows 10 ISO
# (CDI supports HTTP import — point at your Windows ISO server)
kubectl apply -f - <<YAML
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata:
  name: win10-install
  namespace: vms
spec:
  source:
    http:
      url: "http://your-server/win10.iso"
  storage:
    accessModes: [ReadWriteOnce]
    resources:
      requests:
        storage: 60Gi
YAML
```

### 2. Install Windows

Boot a KubeVirt VM from the ISO, perform a standard Windows 10 installation.
Use the VNC console for installation:

```bash
kubectl get vmi -n vms   # get VM name
# Access VNC via the analyst portal noVNC endpoint
```

### 3. Install Sysmon

Download Sysmon from Microsoft Sysinternals and install with the SwiftOnSecurity config:

```powershell
# On the Windows VM
$url = "https://download.sysinternals.com/files/Sysmon.zip"
Invoke-WebRequest $url -OutFile C:\Tools\Sysmon.zip
Expand-Archive C:\Tools\Sysmon.zip -DestinationPath C:\Tools\Sysmon\

# Install with config (config will be updated by detonate.ps1 at runtime)
C:\Tools\Sysmon\Sysmon64.exe -accepteula -i
```

### 4. Configure auto-run

Create a registry key and scheduled task so `detonate.ps1` runs on login:

```powershell
# Create the Detonate registry key (values filled by sidecar at job start)
New-Item -Path "HKLM:\SOFTWARE\Detonate" -Force

# Create a scheduled task to run detonate.ps1 at logon
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -NonInteractive -File C:\Tools\detonate.ps1"
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "Detonate" -Action $action `
    -Trigger $trigger -RunLevel Highest -Force
```

### 5. Configure Windows for analysis

```powershell
# Disable Windows Defender real-time protection
Set-MpPreference -DisableRealtimeMonitoring $true

# Add exclusion for tools directory
Add-MpPreference -ExclusionPath "C:\Tools\"

# Enable audit process creation in Security log
auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable

# Allow outbound from C:\Tools to sidecar (adjust CIDR to your pod network)
New-NetFirewallRule -DisplayName "Detonate Outbound" `
    -Direction Outbound -Action Allow `
    -Program "C:\Tools\*" -RemoteAddress "10.244.0.0/16"
```

### 6. Create the C:\Tools directory structure

```powershell
New-Item -ItemType Directory -Path "C:\Tools" -Force
New-Item -ItemType Directory -Path "C:\Tools\Sysmon" -Force
# detonate.ps1 is downloaded by the sidecar at job start
# sysmonconfig.xml is downloaded from the sidecar /sysmonconfig endpoint
```

### 7. Snapshot as base disk

Once configured, shut down the VM cleanly and snapshot the disk as a
DataVolume PVC in the `vms` namespace:

```bash
# The pool controller looks for a PVC named win10-base-disk-v3 in the vms namespace
# Rename/clone your prepared disk to match this name, or update the pool-controller
# SOURCE_PVC environment variable in analysis/manifests/pool-controller.yaml
```

The pool controller clones this base disk for each detonation job and
deletes the clone when the job completes.

## Updating the base disk

To update Sysmon config, tools, or Windows patches:
1. Start a VM from the current base disk
2. Make your changes
3. Shut down cleanly
4. Update the PVC snapshot
5. Restart the pool controller: `kubectl rollout restart deployment pool-controller -n analyst`
