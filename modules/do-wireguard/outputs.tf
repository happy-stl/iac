output "droplet_ipv4" {
  description = "Public IPv4 address of the WireGuard droplet (the VPN endpoint)."
  value       = digitalocean_droplet.this.ipv4_address
}

output "server_public_key" {
  description = "WireGuard server public key."
  value       = wireguard_asymmetric_key.server.public_key
}

output "client_config" {
  description = "Ready-to-import WireGuard client config for this Mac."
  value       = local.client_config
  sensitive   = true
}

output "project_id" {
  description = "ID of the DigitalOcean Project holding the VPN infra."
  value       = digitalocean_project.this.id
}
