resource "tls_private_key" "default" {
  algorithm = "RSA"
}

resource "local_file" "private_key" {
  filename             = "${path.cwd}/.ssh/${format("%s.pem", tls_private_key.default.public_key_fingerprint_md5)}"
  sensitive_content    = tls_private_key.default.private_key_pem
  file_permission      = "0600"
  directory_permission = "0700"
}


resource "digitalocean_ssh_key" "default" {
  name       = "default"
  public_key = tls_private_key.default.public_key_openssh
}

resource "digitalocean_droplet" "mongo" {
  image    = "ubuntu-18-04-x64"
  name     = "chef-mongo"
  region   = "nyc2"
  size     = "s-1vcpu-1gb"
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
}

module "provision" {
  source = "../.."
  connection = {
    host        = digitalocean_droplet.mongo.ipv4_address
    private_key = tls_private_key.default.private_key_pem
  }
}

output "droplet_ip" {
  value = digitalocean_droplet.mongo.ipv4_address
}
