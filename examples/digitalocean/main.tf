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

resource "digitalocean_droplet" "chef-node" {
  image    = "ubuntu-18-04-x64"
  name     = "chef-server"
  region   = "nyc2"
  size     = "s-1vcpu-1gb"
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
}

resource "local_file" "policyfile" {
  filename = "${path.cwd}/Policyfile.rb"
  content  = <<EOT
name 'chef_client'
default_source :supermarket
cookbook 'chef-client', '~> 11.5.0', :supermarket
run_list 'chef-client::default'
  EOT
}

module "provision" {
  source = "../.."
  connection = {
    host        = digitalocean_droplet.chef-node.ipv4_address
    private_key = tls_private_key.default.private_key_pem
  }
  policyfile          = local_file.policyfile.filename
  chef_client_version = 16.6
}

output "droplet_ip" {
  value = digitalocean_droplet.chef-node.ipv4_address
}
