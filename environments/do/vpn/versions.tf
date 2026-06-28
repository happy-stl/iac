terraform {
  required_version = ">= 1.5"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    wireguard = {
      source  = "OJFord/wireguard"
      version = "~> 0.4"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}
