
terraform {
  required_version = ">= 0.13"
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
    local = {
      source = "hashicorp/local"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }
}
