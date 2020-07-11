locals {
  # defaults to /var/chef/policy/<policy_name>
  policy_name        = var.policy_name
  target_install_dir = format("%s/%s", pathexpand(var.install_dir), var.policy_name)
  target_export_dir  = format("%s/%s/export", pathexpand(var.install_dir), var.policy_name)
  policyfile         = pathexpand(var.policyfile)
  policyfile_lock    = format("%s/Policyfile.lock.json", dirname(pathexpand(var.policyfile)))
  local_build_dir    = format("%s/.chefexport", dirname(pathexpand(var.policyfile)))
  host               = var.host
  # The connection block docs say that
  # the private key takes precendence over
  # the password if the private key is provided
  private_key         = var.ssh_password != "" ? false : file(pathexpand(var.ssh_key))
  ssh_user            = var.ssh_user
  ssh_port            = var.ssh_port
  ssh_password        = var.ssh_password != "" ? var.ssh_password : false
  chef_client_version = var.chef_client_version
  policyfile_archive  = var.policyfile_archive != "" ? pathexpand(var.policyfile_archive) : format("%s/", local.local_build_dir)
}

resource "null_resource" "chef_install" {
  provisioner "local-exec" {
    command = format(
      "rm -f %s && chef install --chef-license accept --debug %s",
      local.policyfile_lock,
      local.policyfile,
    )
  }

  provisioner "local-exec" {
    command = format(
      "rm -rfv %s/* && chef export %s %s --force --debug --chef-license accept --archive",
      local.local_build_dir,
      local.policyfile,
      local.local_build_dir
    )
  }

  # this entire block does not need to run if the archive is provided
  count = var.policyfile_archive == "" ? 1 : 0

  triggers = {
    run = var.skip == true ? 0 : timestamp()
  }

}

resource "null_resource" "deliver_archive" {
  depends_on = [null_resource.chef_install]
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = local.ssh_user
      password    = local.ssh_password
      private_key = local.private_key
      host        = local.host
    }

    inline = [
      format("echo creating %s/", local.target_export_dir),
      format("mkdir -p %s/", local.target_export_dir)
    ]
  }

  provisioner "file" {
    # copies contents of the .chefexport directory
    source      = local.policyfile_archive
    destination = format("%s/", local.target_export_dir)

    connection {
      type        = "ssh"
      user        = local.ssh_user
      password    = local.ssh_password
      private_key = local.private_key
      host        = local.host
    }
  }

  triggers = {
    run = var.skip == true ? 0 : timestamp()
  }

}

resource "null_resource" "untar_archive" {
  depends_on = [null_resource.deliver_archive]
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = local.ssh_user
      password    = local.ssh_password
      private_key = local.private_key
      host        = local.host
    }

    inline = [
      format("mkdir -p %s/source", local.target_install_dir),
      format(
        "tar -xvf $(ls -t %s/%s*.tgz | head -n1) -C %s/source",
        local.target_export_dir,
        local.policy_name,
        local.target_install_dir
      ),
      format("ls %s/source", local.target_install_dir),
    ]
  }

  triggers = {
    run = var.skip == true ? 0 : timestamp()
  }
}

resource "null_resource" "chef_client_run" {
  depends_on = [null_resource.untar_archive]
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = local.ssh_user
      password    = local.ssh_password
      private_key = local.private_key
      host        = local.host
    }

    inline = [
      format(
        "curl --location --time-cond %s/installchef.sh --output %s/installchef.sh https://omnitruck.chef.io/install.sh",
        local.target_install_dir,
        local.target_install_dir,
      ),
      format(
        "chmod +x %s/installchef.sh",
        local.target_install_dir,
      ),
      format(
        "echo Installing chef version %s",
        local.chef_client_version
      ),
      # -P chef just installs Chef Infra Client
      format(
        "%s/installchef.sh -P chef -v %s",
        local.target_install_dir,
        local.chef_client_version
      ),
      format(
        "cd %s/source && chef-client --once --log_level info --local-mode --chef-license accept",
        local.target_install_dir,
      )
    ]
  }

  triggers = {
    run = var.skip == true ? 0 : timestamp()
  }

}
