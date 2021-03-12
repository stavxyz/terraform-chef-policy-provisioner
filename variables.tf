variable "policy_name" {
  type        = string
  description = "Policy name. If not supplied here, it is read from your Policyfile."
  default     = ""
}

variable "chef_client_version" {
  type        = string
  description = "Specify the chef-client version to use."
  default     = "16.2"
}

variable "chef_client_log_level" {
  type        = string
  description = "Log level for chef-client. [auto, trace, debug, info, warn, error, fatal]"
  default     = "info"
}

variable "chef_client_logfile" {
  type        = string
  description = "Log file location"
  default     = "chef-client.log"
}

variable "attributes_file" {
  type        = string
  description = "Path to file containing chef attributes."
  default     = ""
}

variable "data_bags" {
  type        = string
  description = "Relative path to your data_bags directory."
  default     = ""
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

variable "policyfile_archive" {
  type        = string
  description = "Relative path to your policyfile archive (.tgz), or to a directory containg your archives. In the latter case, the most recent archive with matching policy group will be used."
  default     = ""
}

variable "skip" {
  type        = bool
  description = "To skip chef provisiong, set this to true"
  default     = false
}

variable "skip_archive_push" {
  type        = bool
  description = "To force skip pushing the archive, set this to true. This is a temporary fix until we have code in place to determine whether the archive has changed since last push/apply."
  default     = false
}

variable "skip_data_bags_push" {
  type        = bool
  description = "To force skip pushing the data_bags, set this to true. This is a temporary fix until we have code in place to determine whether the archive has changed since last push/apply."
  default     = false
}

terraform {
  experiments = [module_variable_optional_attrs]
}

variable "connection" {
  type = object({
    user                = optional(string)
    password            = optional(string)
    host                = string
    port                = optional(number)
    timeout             = optional(string)
    script_path         = optional(string)
    private_key         = optional(string)
    certificate         = optional(string)
    agent               = optional(bool)
    agent_identity      = optional(string)
    host_key            = optional(string)
    bastion_host        = optional(string)
    bastion_host_key    = optional(string)
    bastion_port        = optional(number)
    bastion_user        = optional(string)
    bastion_password    = optional(string)
    bastion_private_key = optional(string)
    bastion_certificate = optional(string)
  })

  description = "https://www.terraform.io/docs/language/resources/provisioners/connection.html"
}
