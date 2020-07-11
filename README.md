# Chef Policy Provisioner Terraform Module

Given some instruction for building a policyfile archive,
this module will perform the following provisioning steps
on your targeted infrastructure:

- Build and push policyfile tarball to target machine
  - ssh access required
- ensure chef-client with --local-mode capability is installed
- execute chef-client against the built policyfile archive

Possible bonus features:
  - push logs back to central location or machine executing terraform?
