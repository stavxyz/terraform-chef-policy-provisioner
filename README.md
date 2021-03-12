# Chef Policy Provisioner Terraform Module

This module allows you to provision/bootstrap any number of nodes with Chef Policyfiles. **No Chef Server Required!**

### What you will need

* A [Policyfile](https://docs.chef.io/policyfile/) which contains your desired machine configuration
* A machine (or machines) to provision.
  * These could be [DigitalOcean Droplets](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs/resources/droplet), EC2 instances, or even a server on your home network
  * As long as you are able to authenticate to the server (either via ssh, or password), this module can provision it

That's it!

### System Requirements

* [Chef Workstation](https://docs.chef.io/workstation/)
  * On macs, this can be installed with `brew install --cask chef-workstation`
* Terraform >= 0.14
  * [`tfenv` is a great way](https://github.com/tfutils/tfenv)  to install/manage your `terraform` cli

## Example

Let's say you have a relatively simple [Policyfile](https://docs.chef.io/policyfile) which bootstraps your machine with docker:


```ruby
name 'docker'
default_source :supermarket
cookbook 'docker', '~> 7.7.0', :supermarket
run_list 'docker::default'
```

and you would like to apply this policy to a VM. For this example let's assume use a [DigitalOcean Droplet](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs/resources/droplet).

Also, for the sake of this example, let's assume your local private key, `~/.ssh/id_rsa` corresponds to [an ssh key you have added to your DigitalOcean profile](https://www.digitalocean.com/docs/droplets/how-to/add-ssh-keys/to-account/) as "my-ssh-key".

```terraform
resource "digitalocean_droplet" "chef-node" {
  image    = "ubuntu-18-04-x64"
  name     = "chef_docker_policy_droplet"
  region   = "nyc2"
  size     = "s-1vcpu-1gb"
  ssh_keys = ["my-ssh-key"]
}


module "policy-provisioner" {
  source     = "stavxyz/policy-provisioner/chef"
  policyfile = "./Policyfile.rb"
  connection = {
    host        = digitalocean_droplet.chef-node.ipv4_address
    private_key = "~/.ssh/id_rsa"
  }
}
```

Now you are ready to `terraform apply`. 

## How does this work? What happens when I run `terraform apply` using this module?

All of the client-side steps are run in an isolated build directory created by this module. First, the chef policy defined by your Policyfile is built using `chef install` (or `chef update` on subsequent runs). This module determines which of those commands to run automatically. One this is complete, a policyfile archive is built from this using `chef export --archive`. This tarball is then pushed to your target machine(s) over ssh to a predetermined path on the target system. By default, this is `/var/chef/policy/<policy_name/...`. Once the transfer of this chef policy archive is complete, it is unpacked (un-tarred) on the target system. The installation of `chef-client` is always verified, and if needed, this module will install `chef-client` for you. Finally, `chef-client` is executed with `--local-mode` against the archive to finishing provisioning your system.



## Features

- Automatically installs `chef-client` _**of your desired version**_ on your target system(s). This allows you to quickly and easily swap out the version of chef-client being used to converge your nodes. By default, the latest stable version of `chef-client` will be used, but you are also able to explicitly specify your desired version of `chef-client` by supplying a value for the `chef_client_version` variable to this module.
- Supports the delivery/use of `data_bags`
  - By specifying a path to your `data_bags` directory as variable `data_bags`
- Supports the delivery/use of attributes that are specified outside of your `Policyfile.rb`
  - By specifying a json file of attributes as variable `attributes_file`
- No Chef Server Required



## Terraform Registry

https://registry.terraform.io/modules/stavxyz/policy-provisioner/chef
