# Deploy Linux Application demo

Playbooks and survey spec for the **Linux - Deploy Application** job template in Ansible Automation Platform.

## Survey variables

The playbook [`ansible/playbook/deploy_linux_app.yml`](ansible/playbook/deploy_linux_app.yml) expects these **extra vars** from the job template survey:

| Variable | Description |
|----------|-------------|
| `app_name` | Single-select list (no default) — pick an app; package and systemd service use the same name |

Import the survey in AAP: **Job Templates → Linux - Deploy Application → Survey → Import** and select [`ansible/survey/deploy_linux_app.json`](ansible/survey/deploy_linux_app.json).

Also enable **Privilege Escalation** on the job template (the playbook uses `become: true`).

## Playbooks

| Playbook | Purpose |
|----------|---------|
| `deploy_linux_app.yml` | Install package and start service (survey-driven) |
| `diagnose_linux_repos.yml` | Print subscription, `dnf repolist`, and `httpd` availability |
| `fix_linux_repos.yml` | Run `dnf makecache` and verify `httpd` is visible to dnf |

## Troubleshooting: `No package httpd available`

On RHEL 8/9, `httpd` is in **AppStream**. This error means dnf cannot see it in **enabled** repositories (common on unregistered or misconfigured workshop hosts).

1. Run **Diagnose** (ad hoc or job): `demo/ansible/playbook/diagnose_linux_repos.yml`
2. On the bastion, fix repos (workshop RHUI or your org subscription), for example:
   - `subscription-manager status`
   - `dnf repolist` (expect BaseOS and AppStream)
   - `sudo dnf install -y httpd` (must succeed before re-running deploy)
3. Optionally run `fix_linux_repos.yml` if only metadata cache was stale.
4. Re-launch **Linux - Deploy Application** and select an application from the survey list.
