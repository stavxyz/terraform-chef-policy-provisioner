variable "policy_name" {
  type        = string
  description = "Policy name. In the future we may be able to infer this intelligently."
  default     = "default"
}

variable "chef_client_version" {
  type        = string
  description = "Specify the chef-client version to use."
  default     = "16.2"
}

variable "install_dir" {
  type        = string
  description = "The directory to untar and install policyfile in on the target system."
  default     = "/var/chef/policy"
}

variable "policyfile" {
  type        = string
  description = "Relative path to your policyfile."
  default     = "./Policyfile.rb"
}

variable "host" {
  type        = string
  description = "Address of host (for ssh purposes)"
}

variable "ssh_key" {
  type        = string
  description = "Local path to your private ssh key."
  default     = "~/.ssh/id_rsa"
}

variable "ssh_user" {
  type        = string
  description = "SSH User Name"
  default     = "root"
}

variable "ssh_port" {
  type        = number
  description = "SSH Port"
  default     = 22
}

variable "ssh_password" {
  type        = string
  description = "SSH Password, if applicable"
  default     = ""
}

variable "skip" {
  type        = string
  description = "To skip chef provisiong, set this to true"
  default     = false
}


