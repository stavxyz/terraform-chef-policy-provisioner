locals {
  # defaults to /var/chef/policy/<policy_name>
  policy_name             = var.policy_name
  target_install_dir      = format("%s/%s", pathexpand(var.install_dir), var.policy_name)
  target_export_dir       = format("%s/export", local.target_install_dir)
  target_src_dir          = format("%s/src", local.target_install_dir)
  policyfile              = pathexpand(var.policyfile)
  policyfile_lock         = format("%s/Policyfile.lock.json", dirname(pathexpand(var.policyfile)))
  _chef_update_or_install = fileexists(local.policyfile_lock) ? "update" : "install"
  local_build_dir         = format("%s/.chefexport", dirname(pathexpand(var.policyfile)))
  host                    = var.host
  # The connection block docs say that
  # the private key takes precendence over
  # the password if the private key is provided
  _private_key_is_path        = try(fileexists(pathexpand(var.ssh_key)), false)
  private_key                 = var.ssh_password != "" ? false : local._private_key_is_path ? file(pathexpand(var.ssh_key)) : var.ssh_key
  ssh_user                    = var.ssh_user
  ssh_port                    = var.ssh_port
  ssh_password                = var.ssh_password != "" ? var.ssh_password : false
  chef_client_version         = var.chef_client_version
  _archive_supplied           = var.policyfile_archive == "" ? false : true
  _archive_supplied_is_file   = try(local._archive_supplied, fileexists(pathexpand(var.policyfile_archive)), false)
  _archive_supplied_is_dir    = local._archive_supplied && (local._archive_supplied_is_file != true) ? true : false
  _archive_supplied_dirname   = local._archive_supplied_is_file ? format("%s/", dirname(pathexpand(var.policyfile_archive))) : format("%s/", pathexpand(var.policyfile_archive))
  _archive_selector           = try(element(sort(fileset(local._archive_supplied_dirname, format("{%s}**.tgz", local.policy_name))), 0), "NO_ARCHIVE_FOUND_FOR_POLICY")
  supplied_policyfile_archive = local._archive_supplied_is_file ? pathexpand(var.policyfile_archive) : local._archive_supplied_is_dir ? local._archive_selector : "💩"
  # if the policyfile archive supplied is a directory, add a trailing slash
  supplied_policyfile_archive_basename = format("%s", basename(trimsuffix(local.supplied_policyfile_archive, "/")))
  chef_client_log_level                = var.chef_client_log_level
  chef_client_logfile                  = var.chef_client_logfile
  data_bags                            = pathexpand(var.data_bags)
  attributes_file_source               = pathexpand(var.attributes_file)
  attributes_file_basename             = format("%s", basename(trimsuffix(local.attributes_file_source, "/")))
  json_attributes                      = var.attributes_file != "" ? format("--json-attributes %s", local.attributes_file_basename) : ""
}

resource "null_resource" "chef_install_or_update" {
  provisioner "local-exec" {
    command = format(
      "chef %s --chef-license accept --debug %s",
      local._chef_update_or_install,
      local.policyfile,
    )
  }

  # this entire block does not need to run if the archive is provided
  count = local._archive_supplied ? 0 : 1

  triggers = {
    run = var.skip == true ? 0 : timestamp()
  }

}

resource "null_resource" "chef_export" {
  depends_on = [null_resource.chef_install_or_update]

  provisioner "local-exec" {
    command = format(
      "touch %s",
      format("%s/%s-%s.chef_export.out", local.local_build_dir, local.policy_name, filesha256(local.policyfile_lock)),
    )
  }

  provisioner "local-exec" {
    command = format(
      "chef export %s %s --force --debug --chef-license accept --archive 2>&1 | tee %s",
      local.local_build_dir,
      local.policyfile,
      local.local_build_dir,
      format("%s/%s-%s.chef_export.out", local.local_build_dir, local.policy_name, filesha256(local.policyfile_lock)),
    )
  }

  # this entire block does not need to run if the archive is provided
  count = local._archive_supplied ? 0 : 1

  triggers = {
    run = var.skip == true ? 0 : timestamp()
  }

}

resource "null_resource" "create_target_dirs" {
  depends_on = [null_resource.chef_install_or_update]
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
      format("mkdir -v -p %s/", local.target_export_dir),
      format("echo creating %s/", local.target_src_dir),
      format("mkdir -v -p %s/", local.target_src_dir),
    ]
  }
  triggers = {
    run = var.skip == true ? 0 : timestamp()
  }

}


resource "null_resource" "deliver_archive" {
  depends_on = [null_resource.create_target_dirs]

  provisioner "file" {
    source = local._archive_supplied ? local.supplied_policyfile_archive : trimspace(replace(file(format("%s/%s-%s.chef_export.out", local.local_build_dir, local.policy_name, filesha256(local.policyfile_lock))), "/Exported policy .* to /", ""))

    #   attributes_file_basename = format("%s", basename(trimsuffix(local.attributes_file_source, "/")))


    destination = local._archive_supplied ? format("%s/%s", local.target_export_dir, local.supplied_policyfile_archive_basename) : format(
      "%s/%s",
      local.target_export_dir,
      basename(trimsuffix(trimspace(replace(file(
        format(
          "%s/%s-%s.chef_export.out",
          local.local_build_dir,
          local.policy_name,
          filesha256(local.policyfile_lock)
        )
      ), "/Exported policy .* to /", "")), "/"))
    )

    connection {
      type        = "ssh"
      user        = local.ssh_user
      password    = local.ssh_password
      private_key = local.private_key
      host        = local.host
    }
  }
  # only deliver the archive if the archive has been updated
  count = var.skip_archive_push || (var.skip == true) ? 0 : 1
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
      format(
        "tar -xvf \"$(ls -t %s/%s*.tgz | head -n1)\" -C %s",
        local.target_export_dir,
        local.policy_name,
        local.target_src_dir
      ),
      format("ls %s", local.target_src_dir),
    ]
  }

  triggers = {
    run = var.skip == true ? 0 : timestamp()
  }
}

resource "null_resource" "deliver_attributes_file" {
  depends_on = [null_resource.untar_archive]
  provisioner "file" {
    source      = trimsuffix(local.attributes_file_source, "/")
    destination = format("%s/%s", local.target_src_dir, local.attributes_file_basename)

    connection {
      type        = "ssh"
      user        = local.ssh_user
      password    = local.ssh_password
      private_key = local.private_key
      host        = local.host
    }
  }
  # only deliver the attributes file if the file has been changed
  count = (var.attributes_file == "") || (var.skip == true) ? 0 : 1
  triggers = {
    attributes_file_hash = filesha256(local.attributes_file_source)
    run                  = var.skip == true ? 0 : timestamp()
  }
}

resource "null_resource" "deliver_data_bags" {
  depends_on = [null_resource.untar_archive]
  provisioner "file" {
    # no trailing slash ensured so that the dir name comes with
    source      = trimsuffix(local.data_bags, "/")
    destination = format("%s", local.target_src_dir)

    connection {
      type        = "ssh"
      user        = local.ssh_user
      password    = local.ssh_password
      private_key = local.private_key
      host        = local.host
    }
  }
  # TODO: in the future, zip the data bags, check hash, send archive
  # only deliver the data_bags if they have been changed
  count = (local.data_bags == "") || (var.skip == true) ? 0 : 1
  triggers = {
    # TODO: this doesnt work on a directory
    #data_bags_hash = filesha256(local.data_bags)
    run = var.skip == true ? 0 : timestamp()
  }
}



resource "null_resource" "ensure_chef_client" {
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
        "%s/installchef.sh -P chef -v %s || sudo %s/installchef.sh -P chef -v %s",
        local.target_install_dir,
        local.chef_client_version,
        local.target_install_dir,
        local.chef_client_version
      ),
    ]
  }

  triggers = {
    run = var.skip == true ? 0 : timestamp()
  }

}

resource "null_resource" "chef_client_run" {
  depends_on = [null_resource.ensure_chef_client, null_resource.deliver_attributes_file, null_resource.deliver_data_bags]
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
        "cd %s",
        local.target_src_dir,
      ),
      "chef-client --version",
      "pwd",
      format(
        "sudo chef-client --always-dump-stacktrace --once --log_level %s --logfile %s --local-mode --chef-license accept %s",
        local.chef_client_log_level,
        local.chef_client_logfile,
        local.json_attributes,
      )
    ]
  }

  triggers = {
    run = var.skip == true ? 0 : timestamp()
  }

}
