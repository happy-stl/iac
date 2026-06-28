output "vpn_endpoint" {
  description = "Public IPv4 of the VPN server."
  value       = module.vpn.droplet_ipv4
}

output "server_public_key" {
  description = "WireGuard server public key."
  value       = module.vpn.server_public_key
}

output "client_config_file" {
  description = "Path to the generated WireGuard client config on this Mac."
  value       = local_sensitive_file.client_config.filename
}

output "project_id" {
  description = "ID of the DigitalOcean Project holding the VPN infra."
  value       = module.vpn.project_id
}
