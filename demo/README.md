# Deploy Linux Application demo

Playbooks and survey spec for the **Linux - Deploy Application** job template in Ansible Automation Platform.

## Survey variables

The playbook `[ansible/playbook/deploy_linux_app.yml](ansible/playbook/deploy_linux_app.yml)` expects these **extra vars** from the job template survey:


| Variable   | Description                                                                                  |
| ---------- | -------------------------------------------------------------------------------------------- |
| `app_name` | Single-select list (no default) — pick an app; package and systemd service use the same name |


Import the survey in AAP: **Job Templates → Linux - Deploy Application → Survey → Import** and select `[ansible/survey/deploy_linux_app.json](ansible/survey/deploy_linux_app.json)`.

Also enable **Privilege Escalation** on the job template (the playbook uses `become: true`).

## Playbooks


| Playbook                  | Purpose                                                                   |
| ------------------------- | ------------------------------------------------------------------------- |
| `deploy_linux_app.yml`    | Install package and start service (requires working `dnf` repos)          |
| `configure_linux_app.yml` | **No package install** — file, web page, service restart, or host summary |


### Configure without installing packages

Use when the bastion is **not registered** and `dnf install` fails. Import survey `[ansible/survey/configure_linux_app.json](ansible/survey/configure_linux_app.json)` on a **new** job template pointing at `demo/ansible/playbook/configure_linux_app.yml`.


| Survey variable | Values                                                                              |
| --------------- | ----------------------------------------------------------------------------------- |
| `demo_action`   | `write_demo_config`, `write_web_page`, `restart_service`, `host_summary`            |
| `app_name`      | Optional for `write_demo_config` / `host_summary`; required for web/restart actions |



| Action              | What it does                                                                                   |
| ------------------- | ---------------------------------------------------------------------------------------------- |
| `write_demo_config` | Creates `/etc/ansible-demo/deployed.json` with host and timestamp                              |
| `write_web_page`    | Writes `index.html` under `/var/www/html`, `/usr/share/nginx/html`, or `/tmp/ansible-demo-www` |
| `restart_service`   | Restarts `app_name` **only if** the systemd unit already exists                                |
| `host_summary`      | Prints OS, kernel, and network info (no changes)                                               |


