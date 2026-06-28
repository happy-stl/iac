variable "do_token" {
  description = "DigitalOcean API token. Prefer the DIGITALOCEAN_TOKEN env var over setting this."
  type        = string
  default     = null
  sensitive   = true
}

variable "name" {
  description = "Name for the droplet / firewall / SSH key."
  type        = string
  default     = "wireguard-vpn"
}

variable "project_name" {
  description = "Name of the DigitalOcean Project (\"space\") that holds the VPN infra."
  type        = string
  default     = "wireguard-vpn"
}

variable "region" {
  description = "DigitalOcean region slug (pick one close to you, e.g. nyc3, sfo3, ams3, lon1, sgp1)."
  type        = string
  default     = "nyc3"
}

variable "size" {
  description = "Droplet size slug. Default is the cheapest (~$4/mo)."
  type        = string
  default     = "s-1vcpu-512mb-10gb"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key used for admin access to the droplet."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_allowed_cidrs" {
  description = "CIDRs allowed to SSH into the droplet. Restrict to your IP for better security."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "client_config_path" {
  description = "Where to write the generated WireGuard client config on this Mac."
  type        = string
  default     = "generated/wireguard-client.conf"
}
