provider "digitalocean" {
  # Reads the token from the DIGITALOCEAN_TOKEN (or DIGITALOCEAN_ACCESS_TOKEN)
  # environment variable when do_token is left null.
  token = var.do_token
}

provider "wireguard" {}

provider "local" {}
