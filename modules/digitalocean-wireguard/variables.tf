variable "name" {
  description = "Name used for the droplet, SSH key, and firewall."
  type        = string
  default     = "wireguard-vpn"
}

variable "region" {
  description = "DigitalOcean region slug (e.g. nyc3, sfo3, ams3, lon1). Pick one near you."
  type        = string
  default     = "nyc3"
}

variable "size" {
  description = "Droplet size slug. The default is the cheapest droplet (~$4/mo)."
  type        = string
  default     = "s-1vcpu-512mb-10gb"
}

variable "image" {
  description = "Droplet base image."
  type        = string
  default     = "ubuntu-24-04-x64"
}

variable "ssh_public_key" {
  description = "Contents of the SSH public key used for admin access to the droplet."
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "CIDRs allowed to reach SSH (port 22). Restrict to your IP for better security."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "listen_port" {
  description = "UDP port WireGuard listens on."
  type        = number
  default     = 51820
}

variable "vpn_subnet_cidr" {
  description = "Private subnet used inside the WireGuard tunnel."
  type        = string
  default     = "10.66.66.0/24"
}

variable "server_vpn_ip" {
  description = "WireGuard server address inside the tunnel."
  type        = string
  default     = "10.66.66.1"
}

variable "client_vpn_ip" {
  description = "WireGuard address assigned to this Mac client inside the tunnel."
  type        = string
  default     = "10.66.66.2"
}

variable "client_dns" {
  description = "DNS server pushed to the client (full-tunnel browsing needs a resolver)."
  type        = string
  default     = "1.1.1.1"
}

variable "client_allowed_ips" {
  description = "Traffic the client routes through the VPN. 0.0.0.0/0,::/0 = full tunnel."
  type        = string
  default     = "0.0.0.0/0, ::/0"
}

variable "tags" {
  description = "Tags applied to the droplet."
  type        = list(string)
  default     = ["wireguard", "vpn"]
}

variable "project_name" {
  description = "Name of the DigitalOcean Project (the \"space\") that holds the VPN infra."
  type        = string
  default     = "wireguard-vpn"
}

variable "project_description" {
  description = "Description shown on the DigitalOcean Project."
  type        = string
  default     = "WireGuard VPN infrastructure (managed by Terraform)."
}

variable "project_environment" {
  description = "DigitalOcean Project environment. One of: Development, Staging, Production."
  type        = string
  default     = "Production"

  validation {
    condition     = contains(["Development", "Staging", "Production"], var.project_environment)
    error_message = "project_environment must be one of Development, Staging, or Production."
  }
}
