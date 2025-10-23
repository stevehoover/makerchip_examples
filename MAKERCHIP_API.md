# Makerchip REST API Documentation

Reverse-engineered from the [makerchip-app](https://pypi.org/project/makerchip-app/) package on PyPI.

## Overview

Makerchip provides a REST API for creating and managing temporary public projects programmatically. This is used by the `makerchip-app` command-line tool to enable local TL-Verilog/Verilog development with the Makerchip IDE.

## Base URL

- **Production**: `https://makerchip.com/`
- **Alternative**: `https://app.makerchip.com/` (may have different access requirements)

## Authentication

All API requests require session-based authentication using cookies.

### Authenticate

```http
GET /auth/pub/
```

**Response**: Sets session cookies

**Example**:
```bash
curl -c cookies.txt https://makerchip.com/auth/pub/
```

## Project Management

### Create Public Project

Creates a new temporary public project on the Makerchip server.

```http
POST /project/public/
Content-Type: application/x-www-form-urlencoded
```

**Parameters**:
- `name` (required): Project/file name (e.g., `counter.tlv`)
- `source` (required): Design source code (TL-Verilog or Verilog)
- `vcd` (optional): VCD waveform file contents for debugging

**Response**:
```json
{
  "path": "PROJECT_ID"
}
```

**Example**:
```bash
curl -b cookies.txt -X POST \
  -d "name=example.tlv" \
  -d "source=\m5_TLV_version 1d..." \
  https://makerchip.com/project/public/
```

### Get Design Contents

Retrieves the current source code of a project.

```http
GET /project/public/{project_id}/contents
```

**Response**:
```json
{
  "value": "source code here"
}
```

**Example**:
```bash
curl -b cookies.txt https://makerchip.com/project/public/066hGD/contents
```

### Delete Project

Deletes a project from the server.

```http
GET /project/public/{project_id}/delete
```

**Example**:
```bash
curl -b cookies.txt https://makerchip.com/project/public/066hGD/delete
```

### Browser URL

To open a project in the Makerchip IDE:

```
https://makerchip.com/sandbox/public/{project_id}
```

## Server-Sent Events (SSE)

The API uses Server-Sent Events for real-time communication between the desktop app and the web IDE.

### Desktop Events Stream

```http
GET /project/public/{project_id}/desktopEvents
Accept: text/event-stream
```

**Events**:
- `attach`: Editor has opened the project
- `save`: User requested save (desktop app should sync local file)
- `detach`: Editor has closed (desktop app should exit)
- `heartbeat`: Keep-alive ping

**Example**:
```bash
curl -b cookies.txt -H "Accept: text/event-stream" \
  https://makerchip.com/project/public/066hGD/desktopEvents
```

## Usage Examples

### Python Example

See `create_makerchip_project.py` for a complete Python implementation using the `requests` library.

```python
import requests
from urllib.parse import urljoin

session = requests.Session()

# 1. Authenticate
session.get("https://makerchip.com/auth/pub/")

# 2. Create project
resp = session.post(
    "https://makerchip.com/project/public/",
    data={
        "name": "counter.tlv",
        "source": "\\m5_TLV_version 1d: tl-x.org\n..."
    }
)
proj_id = resp.json()['path']

# 3. Get browser URL
url = f"https://makerchip.com/sandbox/public/{proj_id}"
print(f"Open: {url}")

# 4. Cleanup
session.get(f"https://makerchip.com/project/public/{proj_id}/delete")
```

### Bash/curl Example

See `create_makerchip_project.sh` for a complete bash implementation.

```bash
#!/bin/bash
SERVER="https://makerchip.com"
COOKIE_JAR="cookies.txt"

# Authenticate
curl -s -c "$COOKIE_JAR" "${SERVER}/auth/pub/"

# Create project
RESPONSE=$(curl -s -b "$COOKIE_JAR" -X POST \
  --data-urlencode "name=counter.tlv" \
  --data-urlencode "source=\m5_TLV_version..." \
  "${SERVER}/project/public/")

# Extract project ID
PROJ_ID=$(echo "$RESPONSE" | jq -r '.path')

# Open in browser
echo "https://makerchip.com/sandbox/public/${PROJ_ID}"

# Cleanup
curl -s -b "$COOKIE_JAR" "${SERVER}/project/public/${PROJ_ID}/delete"
```

## Notes

1. **Session Management**: The API uses cookie-based sessions. All requests after `/auth/pub/` must include the session cookies.

2. **Project Lifetime**: Public projects are temporary and may expire after inactivity. The makerchip-app keeps projects alive by maintaining an SSE connection.

3. **URL Encoding**: When using POST data, ensure proper URL encoding of the `source` parameter, especially for backslashes and special characters common in TL-Verilog.

4. **Concurrency**: Each project supports a single editor connection. Opening the same project URL in multiple tabs may cause conflicts.

5. **Rate Limiting**: The API may have rate limits. Be respectful when making automated requests.

## Related Resources

- [Makerchip IDE](https://makerchip.com/)
- [TL-Verilog Documentation](http://tl-x.org/)
- [makerchip-app on PyPI](https://pypi.org/project/makerchip-app/)
- [makerchip-app Source Code](https://gitlab.com/rweda/makerchip-app/)

## Test Results

Successfully tested on 2025-10-23:

```
Makerchip REST API Demo (curl version)
======================================================
Authenticating... ✓ Authenticated
Creating project... ✓ Project created: 066hGD

🌐 Open in browser: https://makerchip.com/sandbox/public/066hGD
📋 Project ID: 066hGD

Fetching design contents... ✓ Retrieved 238 characters

✓ Project deleted
```
