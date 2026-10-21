# VECTR module

Deploys a VECTR CE server on an Ubuntu 22.04 EC2 host using the official Docker
Compose runtime. Secrets are generated into Secrets Manager and injected at boot.

## Access
- **With ALB (default):** reach `https://<vectr_hostname>`; point DNS at the ALB.
- **SSM-only (no public ingress):** leave `allowed_cidrs` empty and port-forward:
  ```bash
  aws ssm start-session --target <instance_id> \
    --document-name AWS-StartPortForwardingSession \
    --parameters 'portNumber=8081,localPortNumber=8081'
  ```

## First login
`admin` / `11_ThisIsTheFirstPassword_11` — **change on first login.**

## API
TimberLake and automation use VECTR's GraphQL API. Create an API key in VECTR
(User menu → API keys) and store it for the `timberlake` module.

## Notes
- x86-64 only (ARM unsupported). Default `t3a.medium`, 120 GB gp3.
- To upgrade, bump `vectr_version` and follow VECTR's upgrade guide for data
  migrations before replacing the host.
