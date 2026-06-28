# CLAUDE.md

Guidance for AI agents (and humans) working in this repository.

## What this repo is

Terraform infrastructure-as-code for multiple cloud providers. It provisions
cloud infrastructure only. Machine/OS configuration management lives in the
separate `ansible` repo — do not add Ansible here.

## Repository structure

```
modules/<provider>-<thing>/        Reusable, provider-specific modules
environments/<provider>/<project>/ Root configs (one Terraform state each)
scripts/                           Helper scripts (e.g. VPN connect/disconnect)
```

- **Provider slugs** are short: `do` (DigitalOcean), `gcp` (Google Cloud),
  `aws` (AWS). Use these for both `environments/<provider>/` and the
  `modules/<provider>-*` prefix.
- **An environment is a single Terraform root** at
  `environments/<provider>/<project>/` with its own local state. Examples:
  `environments/do/vpn`, `environments/gcp/project_name_1`,
  `environments/do/project_name_2`.
- **Modules are reusable building blocks**, named `modules/<provider>-<thing>`
  (e.g. `modules/digitalocean-wireguard`). Environments call modules via a
  relative source path. From `environments/<provider>/<project>/` the repo root
  is three levels up: `source = "../../../modules/<name>"`.

## Adding a new environment

1. Create `environments/<provider>/<project>/` containing:
   - `versions.tf`   — `required_version` + `required_providers` (pin with `~>`).
   - `providers.tf`  — provider blocks. Read credentials from env vars; expose an
     optional `*_token` variable defaulting to `null` rather than hardcoding.
   - `variables.tf`  — inputs, with descriptions and sensible defaults.
   - `main.tf`       — module calls / resources.
   - `outputs.tf`    — useful outputs (IPs, IDs, generated file paths).
   - `terraform.tfvars.example` — copyable sample (real `terraform.tfvars` is
     gitignored).
2. Prefer wrapping non-trivial infra in a `modules/<provider>-<thing>` module and
   calling it from the environment, so it can be reused across projects.
3. Keep each environment scoped to one logical concern. On DigitalOcean, group an
   environment's resources into their own `digitalocean_project` ("space") so
   infra stays isolated per project. Other providers: use the native grouping
   (GCP project, AWS account/tags).

## Conventions

- **Secrets/credentials**: never commit them. Use environment variables
  (`DIGITALOCEAN_TOKEN`, `GOOGLE_CREDENTIALS`, `AWS_PROFILE`, etc.). Tokens passed
  as variables must be `sensitive = true` and default to `null`.
- **State**: local by default; each environment has independent state. Do not
  share state across environments. If a remote backend is added later, configure
  it per-environment in `versions.tf`/`backend` blocks.
- **Generated secrets** (e.g. WireGuard client configs, keys) go in a
  `generated/` dir inside the environment and are gitignored. `*.conf` and
  `**/generated/` are already ignored; never commit private keys.
- **Commit `.terraform.lock.hcl`** for each environment; never commit
  `.terraform/`, `*.tfstate`, or `*.tfvars` (except `*.tfvars.example`).
- **Formatting/validation**: run `terraform fmt -recursive` and, in each changed
  environment, `terraform init -backend=false && terraform validate` before
  considering work done.
- **Provider versions**: pin with `~>` in `required_providers`.
- **Naming**: resources and variables use `snake_case`; descriptions on all
  variables and outputs.

## Quick checks

```bash
terraform fmt -recursive
cd environments/<provider>/<project>
terraform init -backend=false
terraform validate
```
