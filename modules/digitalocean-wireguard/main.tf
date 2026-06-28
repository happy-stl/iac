resource "wireguard_asymmetric_key" "server" {}

resource "wireguard_asymmetric_key" "client" {}

resource "digitalocean_ssh_key" "this" {
  name       = var.name
  public_key = var.ssh_public_key
}

resource "digitalocean_droplet" "this" {
  name     = var.name
  image    = var.image
  region   = var.region
  size     = var.size
  ssh_keys = [digitalocean_ssh_key.this.fingerprint]
  tags     = var.tags

  user_data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    server_private_key = wireguard_asymmetric_key.server.private_key
    client_public_key  = wireguard_asymmetric_key.client.public_key
    server_vpn_ip      = var.server_vpn_ip
    client_vpn_ip      = var.client_vpn_ip
    listen_port        = var.listen_port
  })
}

resource "digitalocean_firewall" "this" {
  name        = var.name
  droplet_ids = [digitalocean_droplet.this.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.ssh_allowed_cidrs
  }

  inbound_rule {
    protocol         = "udp"
    port_range       = tostring(var.listen_port)
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# A dedicated DigitalOcean Project ("space") that contains only this VPN's infra.
resource "digitalocean_project" "this" {
  name        = var.project_name
  description = var.project_description
  purpose     = "VPN"
  environment = var.project_environment
  resources   = [digitalocean_droplet.this.urn]
}

locals {
  client_config = <<-EOT
    [Interface]
    PrivateKey = ${wireguard_asymmetric_key.client.private_key}
    Address = ${var.client_vpn_ip}/32
    DNS = ${var.client_dns}

    [Peer]
    PublicKey = ${wireguard_asymmetric_key.server.public_key}
    Endpoint = ${digitalocean_droplet.this.ipv4_address}:${var.listen_port}
    AllowedIPs = ${var.client_allowed_ips}
    PersistentKeepalive = 25
  EOT
}
