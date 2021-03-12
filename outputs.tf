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
  value = format("ssh %s@%s %s", coalesce(local.connection.user, "root"), local.connection.host, (local._private_key_is_path ? format("-i %s", local.connection.private_key) : "💩"))
}
