# Optional: Deploy AAP 2.7 on OpenShift

This section is **optional**. The main MCP demo in the repository root assumes Ansible Automation Platform is already running.

Use this path when you have only the **AAP 2.7 operator** installed and need to create a platform instance with:

- Automation Controller
- Event-Driven Ansible (EDA)
- Automation Hub

## Prerequisites

| Requirement | Notes |
|-------------|--------|
| **OpenShift** | 4.12+ |
| **AAP 2.7 operator** | Installed in your namespace (`stable-2.7` channel), CSV phase `Succeeded` |
| **Dedicated namespace** | e.g. `aap` or `ansible-automation-platform` |
| **RWX storage class** | Required for Automation Hub file storage |
| **OpenShift API access** | API URL and bearer token with permission to create resources in the AAP namespace |
| **Ansible** | 2.14+ with `kubernetes.core` collection |

## Repository layout

```
setup/
├── README.md
├── manifests/
│   └── aap-instance.yaml          # Manual oc apply example
└── ansible/
    ├── playbooks/
    │   ├── deploy-aap-instance.yml
    │   └── verify-aap-instance.yml
    └── roles/aap_instance/
```

## Quick start

### 1. Configure OpenShift API access

Create `ansible/inventory/group_vars/all/openshift.yml` (gitignored) with your credentials:

```yaml
openshift_api_server: "https://api.<cluster>.<domain>:6443"
openshift_token: "<openshift-token>"
openshift_validate_certs: true
```

Or pass values at runtime with `-e openshift_api_server=... -e openshift_token=...`.

### 2. Install Ansible dependencies

```bash
cd setup/ansible
ansible-galaxy collection install -r requirements.yml
```

### 3. Find a ReadWriteMany storage class

Automation Hub requires RWX storage when using `storage_type: file`:

```bash
oc get storageclass
```

### 4. Deploy the AAP instance

```bash
ansible-playbook playbooks/deploy-aap-instance.yml \
  -e openshift_api_server=https://api.<cluster>.<domain>:6443 \
  -e openshift_token=<token> \
  -e aap_namespace=aap \
  -e aap_cr_name=my-aap \
  -e hub_file_storage_storage_class=azurefile-csi
```

| Variable | Default | Description |
|----------|---------|-------------|
| `openshift_api_server` | *(required)* | OpenShift API URL |
| `openshift_token` | *(required)* | Bearer token for the API |
| `openshift_validate_certs` | `true` | Verify TLS certificate for the API |
| `aap_namespace` | `aap` | Namespace where the operator is installed |
| `aap_cr_name` | *(required)* | Name for the new `AnsibleAutomationPlatform` CR |
| `controller_disabled` | `false` | Set `true` to skip Controller |
| `eda_disabled` | `false` | Set `true` to skip EDA |
| `hub_disabled` | `false` | Set `true` to skip Automation Hub |
| `hub_storage_type` | `file` | Hub storage backend |
| `hub_file_storage_storage_class` | `azurefile-csi` | RWX storage class when using file storage (Azure/ARO default) |
| `hub_file_storage_size` | `10Gi` | Hub PVC size |
| `aap_database_storage_size` | `100Gi` | Platform database PVC size |
| `aap_instance_wait_timeout` | `1800` | Seconds to wait for component deployments |
| `lightspeed_disabled` | `true` | Disable Ansible Lightspeed by default |

### 5. Verify

```bash
ansible-playbook playbooks/verify-aap-instance.yml -e aap_cr_name=my-aap
```

Expect `spec.controller.disabled: false`, `spec.eda.disabled: false`, `spec.hub.disabled: false`, component deployments **Available**, and a Platform Gateway route.

### 6. Continue with the MCP demo

Once the platform is healthy and you have applied your subscription in the Platform Gateway UI:

```bash
cd ../../ansible
ansible-playbook playbooks/install-aap-mcp.yml -e aap_cr_name=my-aap
```

See the [main README](../README.md) for MCP configuration and Cursor setup.

## Manual install (oc apply)

Edit `manifests/aap-instance.yaml` with your CR name, namespace, and RWX storage class, then:

```bash
oc apply -f setup/manifests/aap-instance.yaml
```

## Troubleshooting

| Symptom | What to try |
|---------|-------------|
| Deploy fails — CR already exists | Use `verify-aap-instance.yml` or delete the existing CR before re-deploying |
| Hub PVC pending | Confirm `hub_file_storage_storage_class` is a valid RWX class |
| Operator not reconciling | Check CSV phase: `oc get csv -n <namespace>` |
| Components slow to start | Increase `aap_instance_wait_timeout`; full install can take 20–30 minutes |

```bash
oc get ansibleautomationplatform -n aap
oc get pods -n aap
oc get route -n aap
```

## References

- [Install AAP Operator from CLI (2.7)](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-assembly_installing_aap_operator_cli)
- [Deploy AAP with components (2.7)](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-proc_operator_link_components)
- [Customize your AAP Operator (2.7)](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-assembly_operator_customize_aap)
