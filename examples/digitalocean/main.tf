resource "digitalocean_droplet" "chef-server" {
  image  = "ubuntu-18-04-x64"
  name   = "chef-server"
  region = "nyc2"
  size   = "s-1vcpu-1gb"
}


module "provision" {
  /*
   * Since this example lives in the module repository,
   * we use a relative path '../..', but typically we would use
   * the github url, like so:
   *
   * source = "github.com/stavxyz/terraform-null-chef-policyfile"
  */
  source     = "../.."
  host       = digitalocean_droplet.chef-server.ipv4_address
}

