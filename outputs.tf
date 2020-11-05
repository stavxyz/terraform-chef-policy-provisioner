output "local_build_dir" {
  value = local.local_build_dir
}

output "policy_name" {
  value = local.policy_name
}

output "destination_directory" {
  value = local.target_src_dir
}

output "ssh_command" {
  value = format("ssh %s@%s %s", local.ssh_user, local.host, (local._private_key_is_path ? format("-i %s", var.ssh_key) : ""))
}
