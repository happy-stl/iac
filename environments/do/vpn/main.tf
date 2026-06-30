module "vpn" {
  source = "../../../modules/do-wireguard"

  name              = var.name
  project_name      = var.project_name
  region            = var.region
  size              = var.size
  ssh_public_key    = file(pathexpand(var.ssh_public_key_path))
  ssh_allowed_cidrs = var.ssh_allowed_cidrs
}

# Write the client config to disk so it can be imported into the WireGuard app
# or used with `wg-quick`. This file contains a private key: keep it secret.
resource "local_sensitive_file" "client_config" {
  content         = module.vpn.client_config
  filename        = "${path.module}/${var.client_config_path}"
  file_permission = "0600"
}
