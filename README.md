# Chef Policy Provisioner Terraform Module

This module allows you to provision/bootstrap any number of nodes with Chef Policyfiles. **No Chef Server Required!**

### What you will need

* A machine (or machines) to provision.
  * These could be [DigitalOcean Droplets](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs/resources/droplet), EC2 instances, or even a server on your home network
  * As long as you are able to authenticate to the server (either via ssh, or password), this module can provision it
* A [Policyfile](https://docs.chef.io/policyfile/) which contains your desired machine configuration

That's it!

## Example

Let's say you have a relatively simple [Policyfile](https://docs.chef.io/policyfile) which bootstraps your machine with chef-client:


```ruby
name 'chef_client'
default_source :supermarket
cookbook 'chef-client', '~> 11.5.0', :supermarket
run_list 'chef-client::default'
```


Quickly and easily define your [chef policies](https://docs.chef.io/policyfile/)

https://registry.terraform.io/modules/stavxyz/policy-provisioner/chef
