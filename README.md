# Chef Policy Provisioner Terraform Module

This module allows you to provision/bootstrap any number of nodes with Chef Policyfiles with just a few lines of code, completely automatically. **No Chef Server Required!**

## What you will need

* A [Policyfile](https://docs.chef.io/policyfile/) which contains your desired machine configuration
* A machine (or machines) to provision.
  * These could be [DigitalOcean Droplets](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs/resources/droplet), EC2 instances, or even a server on your home network
  * As long as you are able to authenticate to the server (either via ssh, or password), this module can provision it

That's it!

## System Requirements

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



# Features

- Automatically installs `chef-client` _**of your desired version**_ on your target system(s). This allows you to quickly and easily swap out the version of chef-client being used to converge your nodes. By default, the latest stable version of `chef-client` will be used, but you are also able to explicitly specify your desired version of `chef-client` by supplying a value for the `chef_client_version` variable to this module.
- Instead of providing the path to a Policyfile, you can optionally supply a path to an existing policyfile archive. This skips the `chef update` and `chef export` steps.
- Supports the delivery/use of `data_bags`
  - By specifying a path to your `data_bags` directory as variable `data_bags`
- Supports the delivery/use of attributes that are specified outside of your `Policyfile.rb`
  - By specifying a json file of attributes as variable `attributes_file`
- No Chef Server Required

# Variables

| **Variable Name** | **Description** | **Default** |
| ------ | ----- | ----- |
| **`policyfile`** | Path to your [Policyfile](https://docs.chef.io/policyfile/) | `./Policyfile.rb` |
| **`chef_client_version`** | The specified chef-client version to use. | `16.10.x` |
| **`policy_name`** | The name of the chef policy. If not supplied here, it is read from your Policyfile. | null |
| **`policyfile_archive`** | If not supplying `policyfile`, this is the path to your policyfile archive (.tgz) | null |
| **`chef_client_log_level`** | Log level for chef-client. [auto, trace, debug, info, warn, error, fatal] | `info` |
| **`chef_client_logfile`** | Log file location (on target machine). | `./chef-client.log` |
| **`attributes_file`** | Path to JSON file containing chef attributes. | null |
| **`data_bags`** | Path to your `data_bags` directory. | null |
| **`install_dir`** | The directory to untar within and where to install the policy archive on the target system. | `/var/chef/policy` |
| **`skip`** | Beta feature. If `true`, do not perform provisioning. | `false` |
| **`skip_archive_push`** | Beta feature. To force skip pushing the archive set this to `true`. This is a temporary workaround until we have better code in place to determine whether the archive has changed since last push/apply. | `false` |
| **`skip_data_bags_push`** | Beta feature. To force skip pushing `data_bags` set this to `true`. This is a temporary workaround until we have better code in place to determine whether the `data_bags` content has changed since last push/apply. | `false` |
| **`connection`** | `object` variable containing all pertinent `ssh` connection info. Requires `host` key. See below, and  https://www.terraform.io/docs/language/resources/provisioners/connection.html for more details. | null |


## `connection` variable

The following attributes are supported by the `connection` object variable:

| Key | Description | Default |
| ----- | ----- | ----- |
| `user` | The user that we should use for the connection. | `root` |
| `password` | The password we should use for the connection. | null |
| `host` | (Required) The address of the resource to connect to. | null |
| `port` | The port to connect to. | `22` |
| `timeout` | The timeout to wait for the connection to become available. Should be provided as a string like 30s or 5m. | `5m` |
| `script_path` | The path used to copy scripts meant for remote execution. | null |
| `private_key` | The path to, or contents of, an SSH key to use for the connection. This takes preference over the password if provided. | null |
| `certificate` | The contents of a signed CA Certificate. The certificate argument must be used in conjunction with a private_key. These can be loaded from a file on disk using the the `file` function. | null |
| `agent` | Set to `false` to disable using ssh-agent to authenticate. | `true` |
| `agent_identity` | The preferred identity from the ssh agent for authentication. | null (auto) |
| `host_key` | The public key from the remote host or the signing CA, used to verify the connection. | null |
| `bastion_host` | Setting this enables the bastion Host connection. This host will be connected to first, and then the `host` connection will be made from there. | null |
| `bastion_host_key` | The public key from the remote host or the signing CA, used to verify the host connection. | null |
| `bastion_port` | The port to use connect to the bastion host. Defaults to the value of the `port` field. | null |
| `bastion_user` | The user for the connection to the bastion host. Defaults to the value of the `user` field. | null |
| `bastion_password` | The password we should use for the bastion host. Defaults to the value of the `password` field. | null |
| `bastion_private_key` | The path to, or contents of, an SSH key file to use for the bastion host. Defaults to the value of the `private_key` field. | null |
| `bastion_certificate` | The contents of a signed CA Certificate. The certificate argument must be used in conjunction with a `bastion_private_key`. These can be loaded from a file on disk using the the `file()` function.| null |


# Terraform Registry

https://registry.terraform.io/modules/stavxyz/policy-provisioner/chef
