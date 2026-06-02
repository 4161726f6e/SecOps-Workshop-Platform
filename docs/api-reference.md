# Analyst Portal API Reference

All endpoints require authentication via session cookie or `X-API-Key` header.

## Authentication

### POST /auth/register
Create a new analyst account.

```json
Request:  { "username": "analyst1", "password": "securepassword" }
Response: { "username": "analyst1", "role": "analyst", "api_key": "..." }
```

### POST /auth/login
```json
Request:  { "username": "analyst1", "password": "securepassword" }
Response: { "username": "analyst1", "role": "analyst" }
          Sets session cookie.
          Returns { "force_password_change": true } if password change required.
```

### POST /auth/logout
Clears session cookie.

### POST /auth/change-password
```json
Request: { "current_password": "old", "new_password": "new" }
```

### GET /auth/me
```json
Response: { "username": "analyst1", "role": "analyst", "has_api_key": true }
```

---

## Artifacts

### POST /api/artifacts
Upload a file for analysis. Multipart form upload.

```
Form fields: file (binary)
Response: { "artifact_id": "uuid", "filename": "...", "sha256": "..." }
```

Deduplicates by SHA256 — returns existing artifact_id if already uploaded.

### GET /api/artifacts
List artifacts (own only for analysts; all for admins).

```json
Response: [{ "id": "uuid", "filename": "...", "sha256": "...",
             "size_bytes": 12345, "mime_type": "...", "uploaded_at": "..." }]
```

### DELETE /api/artifacts/{artifact_id}
Delete artifact and all associated jobs and reports.

---

## Jobs

### POST /api/jobs
Submit an analysis job. Multipart form.

```
Form fields:
  artifact_id   UUID of uploaded artifact
  analysis_type static-binary | static-pcap | detonate
Response: { "job_id": "uuid", "status": "running", "namespace": "analysis-..." }
```

### GET /api/jobs
List jobs (own only for analysts; all for admins).

### GET /api/jobs/{job_id}/report
Fetch completed report JSON.

```json
Response: { "report": "<json string>" }
```

### GET /api/jobs/{job_id}/stream
Server-Sent Events stream for live job status updates.

```
event: data
data: { "job_id": "...", "status": "running", "queue_pos": 0, "est_wait_sec": 300 }
```

### DELETE /api/jobs/{job_id}
Cancel a pending or running job.

---

## Account

### GET /api/account/apikey
Get API key placeholder (raw keys not stored).

### POST /api/account/apikey/regenerate
Regenerate API key. Returns new raw key once.

```json
Response: { "api_key": "new-raw-key" }
```

---

## Admin (admin role only)

### GET /admin/users
List all users.

### POST /admin/users/{username}/deactivate
Deactivate user and all their API keys.

---

## Job Status Page

`GET /jobs/{job_id}` — Full-page SSE-driven status view.

Displays live phase progression for detonation jobs:
- 0s: Queued
- 0–420s: Cloning VM disk
- 420–480s: Booting VM
- 480–600s: Executing sample + dwell
- Done: Inline report

---

## curl Examples

```bash
# Login and save session
curl -sk -c /tmp/s.txt -X POST https://<host>/ auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"analyst1","password":"password"}' > /dev/null

# Upload artifact
curl -sk -b /tmp/s.txt -X POST https://<host>/api/artifacts \
  -F "file=@sample.exe"

# Submit job
curl -sk -b /tmp/s.txt -X POST https://<host>/api/jobs \
  -F "artifact_id=<uuid>" \
  -F "analysis_type=static-binary"

# Using API key instead of session
curl -sk -H "X-API-Key: <your-api-key>" \
  https://<host>/api/jobs
```
