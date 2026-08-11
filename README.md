# Ansible Automation Platform MCP server on OpenShift

Demo repository for enabling the **Ansible MCP server** (Technology Preview in AAP 2.6.4+) on an existing **Ansible Automation Platform** deployment on **OpenShift**, then connecting **Cursor** (or another MCP client) to your automation estate.

## What you get

The MCP server is deployed by the **AAP operator** when you enable the `mcp` component on the `AnsibleAutomationPlatform` custom resource. The operator creates the workload (for example deployment `aap-mcp`) and **OpenShift routes** for HTTPS access. AI clients call toolset endpoints such as `https://<mcp-route-host>/job_management/mcp` using a **Bearer token** that inherits your AAP RBAC permissions. On OpenShift, use the **MCP route** (not the Platform Gateway route).

## Prerequisites

| Requirement | Notes |
|-------------|--------|
| **OpenShift** | 4.12+ (validated patterns often reference 4.17–4.20) |
| **AAP 2.6.4+** | MCP server is Technology Preview; patch level matters |
| **AAP operator** | Installed, `AnsibleAutomationPlatform` CR reconciled and healthy |
| **OpenShift API access** | API URL and bearer token with permission to patch resources in the AAP namespace |
| **Ansible** | 2.14+ with `kubernetes.core` collection |
| **Subscription** | Valid AAP subscription applied in Platform Gateway |
| **MCP client** | Cursor, Claude, VS Code, etc. |

Recommended namespace for AAP 2.6 on OpenShift: **`aap`**.

> **Don't have AAP yet?** If you only have the operator installed, see [`setup/README.md`](setup/README.md) to deploy Controller, EDA, and Automation Hub first. That path is optional — the MCP demo below requires an existing AAP instance.

> **Technology Preview:** Not covered by production SLAs. Use for demos and evaluation, not production-critical automation without your own risk acceptance.
>
> **Read-write mode (default):** The install playbook sets `allow_write_operations: true`. The AI agent can launch jobs and change AAP when your OAuth token has write scope. Use `-e mcp_allow_write=false` or `manifests/aap-mcp-patch-readonly.yaml` for read-only.

## Repository layout

```
.
├── ansible/
│   ├── inventory/group_vars/all/     # AAP and OpenShift variables
│   ├── playbooks/
│   │   ├── install-aap-mcp.yml       # Enable MCP via CR patch + wait
│   │   ├── verify-aap-mcp.yml        # Check CR, deployments, routes
│   │   └── generate-cursor-config.yml
│   └── roles/aap_mcp/
├── manifests/                          # Manual oc patch examples
├── examples/
│   ├── cursor-mcp.json.example
│   └── cursor-mcp.generated.json       # Created by generate-cursor-config
└── scripts/set-cursor-mcp-token.sh
```

## Quick start

Ansible runs on **your machine** and calls the **remote** OpenShift API. You do not need a local cluster—only network access and credentials.

### 1. Configure OpenShift API access

Copy `ansible/inventory/group_vars/all/openshift.yml.example` to `all.yml` (do not commit), or pass values at runtime:

```yaml
openshift_api_server: "https://api.<cluster>.<domain>:6443"
openshift_token: "<openshift-token>"
openshift_validate_certs: true
```

Get a token from the OpenShift web console (**Copy login command**) or use a [service account token](https://docs.redhat.com/en/documentation/openshift_container_platform/4.16/html/authentication_and_authorization/using-service-accounts-as-oauth-client) with access to the `aap` namespace. See also `examples/openshift-connection.env.example`.

### 2. Install Ansible dependencies

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
```

### 3. Enable the MCP server

```bash
ansible-playbook playbooks/install-aap-mcp.yml
```

| Variable | Default | Description |
|----------|---------|-------------|
| `openshift_api_server` | *(required)* | OpenShift API URL |
| `openshift_token` | *(required)* | Bearer token for the API |
| `openshift_validate_certs` | `true` | Verify TLS certificate for the API |
| `aap_namespace` | `aap` | Namespace of the AAP deployment |
| `aap_cr_name` | *(auto)* | `AnsibleAutomationPlatform` CR name |
| `mcp_allow_write` | `true` | Server-level write access (jobs, changes) |
| `mcp_ignore_cert_errors` | `false` | Set `IGNORE_CERTIFICATE_ERRORS` on MCP |
| `wait_timeout` | `600` | Seconds to wait for MCP deployment |

Example with overrides:

```bash
ansible-playbook playbooks/install-aap-mcp.yml \
  -e openshift_api_server=https://api.<cluster>.<domain>:6443 \
  -e openshift_token=<token> \
  -e aap_cr_name=my-aap \
  -e mcp_allow_write=true
```

### 4. Verify

```bash
ansible-playbook playbooks/verify-aap-mcp.yml
```

Expect `spec.mcp.disabled: false`, deployment `aap-mcp` **Available**, and an MCP route present.

### 5. Generate Cursor MCP config

```bash
ansible-playbook playbooks/generate-cursor-config.yml
```

Writes `examples/cursor-mcp.generated.json` with toolset URLs using your **Platform Gateway** host. Override with `-e aap_mcp_gateway_host=...` or `-e cursor_mcp_config_path=...` if needed.

### 6. Create an OAuth application and token

The MCP server authenticates **as the user who owns the token**. Register an **OAuth application** in the Platform Gateway UI, then create a token linked to it.

Red Hat reference: [Token-based authentication](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/access_management_and_authentication/gw-token-based-authentication).

**Step 1 — Create the OAuth application:** **Access Management → OAuth Applications → Create OAuth application**

| Field | Value |
|-------|-------|
| Name | `cursor-mcp-client` |
| Organization | Your AAP organization (e.g. `Default`) |
| Authorization grant type | **Authorization code** |
| Client type | **Confidential** |
| Redirect URIs | Not used by Cursor; use `https://localhost/callback` if required |

Copy **Client ID** and **Client Secret** when shown (secret is displayed **only once**). Cursor MCP uses the **Bearer token** from Step 2—not the client secret.

**Step 2 — Create a token:** Open the application → **Tokens** tab → **Create token**

| Field | Value |
|-------|-------|
| Application | `cursor-mcp-client` |
| Description | e.g. `Cursor MCP write token` |
| Scope | **Write** for read-write MCP (repo default); **Read** for read-only |

Copy the **Token** immediately—it is shown **only once**.

**Step 3 — Verify (optional):** **Access Management → OAuth Applications** → select your application → **Tokens** tab. Confirm your user appears with the expected scope.

### 7. Connect Cursor

```bash
export MY_AAP_SERVICE_TOKEN='<token-from-aap-ui>'
./scripts/set-cursor-mcp-token.sh
```

Defaults: reads `examples/cursor-mcp.generated.json`, writes `~/.cursor/mcp.json`. Override with `INPUT` and `OUTPUT` env vars.

Alternatively, embed the token at generate time (do not commit the output):

```bash
ansible-playbook playbooks/generate-cursor-config.yml \
  -e aap_mcp_bearer_token="$MY_AAP_SERVICE_TOKEN"
```

Restart Cursor (or reload MCP servers), then ask:

`What MCP tools are available for my Ansible Automation Platform?`

Keep MCP server **names short** (under ~20 characters); many clients limit combined server+tool names to 64 characters.

## MCP toolsets

URL pattern: `https://<mcp-route-host>/<toolset>/mcp` (OpenShift: use the route whose **name contains `mcp`**, not the Platform Gateway route)

| MCP server name | Path segment | Typical use |
|-----------------|--------------|-------------|
| `aap-mcp-job-management` | `job_management` | Job templates, launches, status, logs |
| `aap-mcp-inventory` | `inventory_management` | Hosts, groups, inventories |
| `aap-mcp-monitoring` | `system_monitoring` | Platform health, troubleshooting |
| `aap-mcp-users` | `user_management` | Users, teams, RBAC |
| `aap-mcp-security` | `security_compliance` | Credentials, credential types |
| `aap-mcp-platform` | `platform_configuration` | Settings, licenses, execution environments |

Example `mcp.json` entry:

```json
"aap-mcp-job-management": {
  "type": "streamable-http",
  "url": "https://<mcp-route-host>/job_management/mcp",
  "headers": {
    "Authorization": "Bearer <your-aap-token>"
  }
}
```

Use the **MCP** route hostname from **Networking → Routes** (route name contains `mcp`) or from `generate-cursor-config.yml` output—not the Platform Gateway route.

## Permissions

Two layers control what the AI agent can do:

| MCP server (`allow_write_operations`) | Token scope | Result |
|--------------------------------------|-------------|--------|
| `false` (read-only) | Read or Write | Query only; server blocks writes |
| `true` (repo default) | Read | Query only |
| `true` | Write | Launch jobs and make changes **within the user's RBAC** |

The OAuth/API token inherits normal AAP RBAC—the agent can only do what that user may do.

## Manual install (OpenShift console or `oc patch`)

Add to your `AnsibleAutomationPlatform` CR:

```yaml
spec:
  mcp:
    disabled: false
    allow_write_operations: true   # false for read-only
```

Or apply a merge patch (edit `metadata.name` / `namespace` first):

```bash
oc patch ansibleautomationplatform <CR_NAME> -n aap \
  --type=merge --patch-file manifests/aap-mcp-patch.yaml
```

Read-only: `manifests/aap-mcp-patch-readonly.yaml` or `-e mcp_allow_write=false`.

After reconciliation, confirm deployment `aap-mcp` is running and copy the MCP route **Location**. If you change `allow_write_operations` after the first deploy, delete the **AnsibleMCPServer** instance in the AAP portal (name suffix `-mcp`) so the operator recreates it.

## Troubleshooting

| Symptom | What to try |
|---------|-------------|
| No `aap-mcp` deployment | Confirm AAP ≥ 2.6.4, operator upgraded, `mcp.disabled: false`; check operator logs |
| `400` / certificate errors | `-e mcp_ignore_cert_errors=true` or `manifests/aap-mcp-patch-ignore-certs.yaml` |
| Changed read/write after deploy | Delete **AnsibleMCPServer** CR in AAP portal; wait for recreation |
| `406` from API | Ask the agent to request **JSON** output first, then transform |
| **405 Not Allowed** (nginx) | URLs must use the **MCP OpenShift route** (hostname like `aap26-mcp-…` or `aap-mcp-…`), not the Platform Gateway route (`aap26-aap-…`); set `"type": "streamable-http"` |
| Cursor shows no tools | MCP route hostname, `streamable-http` type, and token set via `set-cursor-mcp-token.sh` |
| Token rejected / 401 | Token expired or revoked; confirm format is `Bearer <token>` |
| Agent reads but cannot launch jobs | MCP read-only mode or token scope is **Read** only |
| Ansible cannot reach cluster | Verify `openshift_api_server`, `openshift_token`, and network access |

```bash
cd ansible
ansible-playbook playbooks/verify-aap-mcp.yml
oc describe deployment aap-mcp -n aap
oc logs -n aap -l app.kubernetes.io/name=aap-mcp --tail=100
```

## References

**New AAP install on OpenShift** — install the operator and `AnsibleAutomationPlatform` CR first, then run `install-aap-mcp.yml`:

- [Installing AAP on OpenShift 2.6](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/installing_on_openshift_container_platform)

**Official MCP documentation:**

- [Deploy Ansible MCP server (AAP 2.6)](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html-single/extend-assembly_deploying_ansible_mcp_server/index)
- [MCP server on OpenShift (install guide)](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/installing_on_openshift_container_platform/deploy-ansible-mcp-server-operator-install)
- [Introducing the MCP server (blog)](https://www.redhat.com/en/blog/it-automation-agentic-ai-introducing-mcp-server-red-hat-ansible-automation-platform)

## License

Documentation and automation in this repo are provided as-is for demonstration. Ansible Automation Platform and the MCP server are subject to Red Hat subscription and Technology Preview terms.
