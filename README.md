# Chef Policy Provisioner Terraform Module

Given some instructions for building a policyfile archive,
this module will perform the following provisioning steps
on your targeted infrastructure:

- Build and push policyfile tarball to target machine
  - ssh access required
- will ensure chef-client with --local-mode capability is installed
- will execute chef-client against the built policyfile archive

## Requirements

The machine executing this terraform configuration must have [chef workstation](https://downloads.chef.io/chef-workstation/) installed.

Chef Workstation provides the `chef` binary which is required for this module to `chef install`, `chef export`, etc.
  

## example

Provision a policyfile-archive based configuration onto a new VM.

```
# main.tf

resource "digitalocean_droplet" "chef-server" {
  image  = "ubuntu-18-04-x64"
  name   = "chef-server"
  region = "nyc2"
  size   = "s-1vcpu-1gb"
}


module "provision" {
  source = "github.com/stavxyz/terraform-null-chef-policyfile"
  host       = digitalocean_droplet.chef-server.ipv4_address
  policyfile = "./Policyfile.rb"
}
```
