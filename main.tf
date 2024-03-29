locals {
  policyfile                       = pathexpand(var.policyfile)
  policy_name                      = var.policy_name != "" ? var.policy_name : lookup(regex("(?ms:(?:(?:^name ){1}(?:['\"]{1})(?P<policy_name>[a-zA-Z0-9-_ ]+)(?:['\"]{1}$)))", file(pathexpand(var.policyfile))), "policy_name")
  target_install_dir               = format("%s/%s", pathexpand(var.install_dir), local.policy_name)
  target_export_dir                = format("%s/export", local.target_install_dir)
  target_src_dir                   = format("%s/src", local.target_install_dir)
  _policyfile_lock                 = replace(basename(local.policyfile), "/.rb$/", ".lock.json")
  policyfile_lock                  = format("%s/%s", dirname(local.policyfile), local._policyfile_lock)
  _chef_update_or_install          = try((fileexists(local.policyfile_lock) ? "update" : "install"), "install")
  local_build_dir                  = format("%s/.terraform/.chef/.%s-workspace/%s", path.module, terraform.workspace, local.policy_name)
  _install_chef_script_name        = "installchef.sh"
  _install_chef_script_source      = format("%s/scripts/%s", path.module, local._install_chef_script_name)
  _install_chef_script_destination = format("%s/%s", local.target_install_dir, local._install_chef_script_name)
  chef_client_version              = var.chef_client_version
  _archive_supplied                = var.policyfile_archive == "" ? false : true
  _archive_supplied_is_file        = try(local._archive_supplied, fileexists(pathexpand(var.policyfile_archive)), false)
  _archive_supplied_is_dir         = local._archive_supplied && (local._archive_supplied_is_file != true) ? true : false
  _archive_supplied_dirname        = local._archive_supplied_is_file ? format("%s/", dirname(pathexpand(var.policyfile_archive))) : format("%s/", pathexpand(var.policyfile_archive))
  _archive_selector                = try(element(sort(fileset(local._archive_supplied_dirname, format("{%s}**.tgz", local.policy_name))), 0), "NO_ARCHIVE_FOUND_FOR_POLICY")
  supplied_policyfile_archive      = local._archive_supplied_is_file ? pathexpand(var.policyfile_archive) : local._archive_supplied_is_dir ? local._archive_selector : "💩"
  # if the policyfile archive supplied is a directory, add a trailing slash
  supplied_policyfile_archive_basename = format("%s", basename(trimsuffix(local.supplied_policyfile_archive, "/")))
  chef_client_log_level                = var.chef_client_log_level
  chef_client_logfile                  = var.chef_client_logfile
  data_bags                            = pathexpand(var.data_bags)
  attributes_file_source               = pathexpand(var.attributes_file)
  attributes_file_basename             = format("%s", basename(trimsuffix(local.attributes_file_source, "/")))
  json_attributes                      = var.attributes_file != "" ? format("--json-attributes %s", local.attributes_file_basename) : ""
}


# connection blocks
locals {

  _private_key_is_path = try(fileexists(pathexpand(var.connection.private_key)), false)
  private_key          = local._private_key_is_path ? file(pathexpand(var.connection.private_key)) : var.connection.private_key

  # bastion_private_key, bastion_port, bastion_password, bastion_user
  # default to the other values provided for the types unless explicitly specified
  _bastion_private_key         = try(coalesce(var.connection.bastion_private_key, var.connection.private_key), var.connection.bastion_private_key)
  _bastion_private_key_is_path = try(fileexists(pathexpand(local._bastion_private_key)), false)
  bastion_private_key          = local._bastion_private_key_is_path ? file(pathexpand(local._bastion_private_key)) : local._bastion_private_key

  bastion_user     = try(coalesce(var.connection.bastion_user, var.connection.user), var.connection.bastion_user)
  bastion_password = try(coalesce(var.connection.bastion_password, var.connection.password), var.connection.bastion_password)
  bastion_port     = try(coalesce(var.connection.bastion_port, var.connection.port), var.connection.bastion_port)

  connection = {
    type                = "ssh"
    user                = var.connection.user
    password            = var.connection.password
    host                = var.connection.host
    port                = var.connection.port
    timeout             = var.connection.timeout
    script_path         = var.connection.script_path
    private_key         = local.private_key
    certificate         = var.connection.certificate
    agent               = var.connection.agent
    agent_identity      = var.connection.agent_identity
    host_key            = var.connection.host_key
    bastion_host        = var.connection.bastion_host
    bastion_host_key    = var.connection.bastion_host_key
    bastion_port        = var.connection.bastion_port
    bastion_user        = var.connection.bastion_user
    bastion_password    = var.connection.bastion_password
    bastion_private_key = local.bastion_private_key
    bastion_certificate = var.connection.bastion_certificate
  }
}



resource "null_resource" "_show_locals" {
  provisioner "local-exec" {
    command = format(<<EOF
cat << OOO
  🔸 policy_name =====> %s
  🔸 policyfile ======> %s
  🔸 local_build_dir => %s
  🔸 target_install_dir => %s
  🔸 target_export_dir => %s
  🔸 target_src_dir => %s
  🔸 policyfile_lock => %s
  🔸 chef_client_version => %s
  🔸 chef_client_log_level => %s
OOO
EOF
      ,
      local.policy_name,
      local.policyfile,
      local.local_build_dir,
      local.target_install_dir,
      local.target_export_dir,
      local.target_src_dir,
      local.policyfile_lock,
      local.chef_client_version,
      local.chef_client_log_level,
    )
  }
}

resource "null_resource" "create_local_build_dir" {
  provisioner "local-exec" {
    command = format(
      "echo '🔨' && mkdir -vp %s",
      local.local_build_dir,
    )
  }
  provisioner "local-exec" {
    command = format(
      "ls %s",
      local.local_build_dir,
    )
  }
  triggers = {
    run       = local.local_build_dir
    workspace = terraform.workspace
  }
}

resource "null_resource" "chef_install_or_update" {
  depends_on = [null_resource.create_local_build_dir]
  # create file to capture stdout from chef update
  provisioner "local-exec" {
    command = format(
      "touch %s",
      format("%s/%s-%s.chef_update.out", local.local_build_dir, local.policy_name, filesha256(local.policyfile)),
    )
  }

  provisioner "local-exec" {
    command = format(
      "chef %s --chef-license accept --debug %s 2>&1 | tee %s",
      local._chef_update_or_install,
      local.policyfile,
      format("%s/%s-%s.chef_update.out", local.local_build_dir, local.policy_name, filesha256(local.policyfile)),
    )
  }

  # this entire block does not need to run if the archive is provided
  count = local._archive_supplied ? 0 : 1

  triggers = {
    run = var.skip == true ? 0 : timestamp()
  }

}

resource "null_resource" "chef_update_if_not_done" {
  depends_on = [null_resource.chef_install_or_update]

  # create file to capture stdout from chef update
  provisioner "local-exec" {
    command = format(
      "touch %s",
      format("%s/%s-%s.chef_update.out", local.local_build_dir, local.policy_name, filesha256(local.policyfile)),
    )
  }


  provisioner "local-exec" {
    command = format(
      "chef update --chef-license accept --debug %s 2>&1 | tee %s",
      local.policyfile,
      format("%s/%s-%s.chef_update.out", local.local_build_dir, local.policy_name, filesha256(local.policyfile)),
    )
  }

  # this entire block does not need to run if:
  #  - the archive was supplied
  #  - if chef update has already run
  # i.e. only run this block if 'chef_update_or_install' executed 'install' instead of 'update'
  count = local._archive_supplied ? 0 : 1
  #count = (local._archive_supplied) || (local._chef_update_or_install == "update") ? 0 : 1

  triggers = {
    run = var.skip == true ? 0 : timestamp()
  }

}


# locals {
#   lockfile        = regex("(?ms:(?:(?:^Lockfile written to ){1}(?P<lockfile>[0-9A-Za-z/-]+.lock.json$)))", file(format("%s/%s-%s.chef_update.out", local.local_build_dir, local.policy_name, filesha256(local.policyfile))))
#   policy_revision = regex("(?ms:(?:(?:^Policy revision id: ){1}(?P<policy_revision>[a-z0-9A-Z]{64}$)))", file(format("%s/%s-%s.chef_update.out", local.local_build_dir, local.policy_name, filesha256(local.policyfile))))
# }

resource "null_resource" "chef_export" {
  depends_on = [null_resource.chef_install_or_update, null_resource.chef_update_if_not_done]

  # create file to capture stdout from chef export
  provisioner "local-exec" {
    command = format(
      "touch %s",
      format(
        "%s/%s-%s.chef_export.out",
        local.local_build_dir,
        local.policy_name,
        lookup(
          regex("(?ms:(?:(?:^Policy revision id: ){1}(?P<policy_revision>[a-z0-9A-Z]{64}$)))",
            file(
              format("%s/%s-%s.chef_update.out",
                local.local_build_dir,
                local.policy_name,
                filesha256(local.policyfile)
              )
            )
          ),
          "policy_revision",
        )
      ),
    )
  }

  # execute chef export
  provisioner "local-exec" {
    command = format(
      "chef export %s %s --force --debug --chef-license accept --archive 2>&1 | tee %s",
      local.policyfile,
      local.local_build_dir,
      format(
        "%s/%s-%s.chef_export.out",
        local.local_build_dir,
        local.policy_name,
        lookup(
          regex("(?ms:(?:(?:^Policy revision id: ){1}(?P<policy_revision>[a-z0-9A-Z]{64}$)))",
            file(
              format("%s/%s-%s.chef_update.out",
                local.local_build_dir,
                local.policy_name,
                filesha256(local.policyfile)
              )
            )
          ),
          "policy_revision",
        )
      ),
    )
  }

  # this entire block does not need to run if the archive is provided
  count = local._archive_supplied ? 0 : 1

  triggers = {
    run = var.skip == true ? 0 : timestamp()
  }

}

resource "null_resource" "create_target_dirs" {
  depends_on = [null_resource.chef_install_or_update, null_resource.chef_update_if_not_done]
  provisioner "remote-exec" {

    connection {
      type                = local.connection.type
      user                = local.connection.user
      password            = local.connection.password
      host                = local.connection.host
      port                = local.connection.port
      timeout             = local.connection.timeout
      script_path         = local.connection.script_path
      private_key         = local.connection.private_key
      certificate         = local.connection.certificate
      agent               = local.connection.agent
      agent_identity      = local.connection.agent_identity
      host_key            = local.connection.host_key
      bastion_host        = local.connection.bastion_host
      bastion_host_key    = local.connection.bastion_host_key
      bastion_port        = local.connection.bastion_port
      bastion_user        = local.connection.bastion_user
      bastion_password    = local.connection.bastion_password
      bastion_private_key = local.connection.bastion_private_key
      bastion_certificate = local.connection.bastion_certificate
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

# only push archive if tarball hash has changed
# only untar if policy revision has changed
#

resource "null_resource" "deliver_archive" {
  depends_on = [null_resource.create_target_dirs, null_resource.chef_export]

  provisioner "file" {
    source = local._archive_supplied ? local.supplied_policyfile_archive : trimspace(replace(file(format("%s/%s-%s.chef_export.out", local.local_build_dir, local.policy_name, lookup(
      regex("(?ms:(?:(?:^Policy revision id: ){1}(?P<policy_revision>[a-z0-9A-Z]{64}$)))",
        file(
          format("%s/%s-%s.chef_update.out",
            local.local_build_dir,
            local.policy_name,
            filesha256(local.policyfile)
          )
        )
      ),
      "policy_revision",
      )
    )), "/Exported policy .* to /", ""))


    destination = local._archive_supplied ? format("%s/%s", local.target_export_dir, local.supplied_policyfile_archive_basename) : format(
      "%s/%s",
      local.target_export_dir,
      basename(trimsuffix(trimspace(replace(file(
        format(
          "%s/%s-%s.chef_export.out",
          local.local_build_dir,
          local.policy_name,
          lookup(
            regex("(?ms:(?:(?:^Policy revision id: ){1}(?P<policy_revision>[a-z0-9A-Z]{64}$)))",
              file(
                format("%s/%s-%s.chef_update.out",
                  local.local_build_dir,
                  local.policy_name,
                  filesha256(local.policyfile)
                )
              )
            ),
            "policy_revision",
          ),
        )
      ), "/Exported policy .* to /", "")), "/"))
    )

    connection {
      type                = local.connection.type
      user                = local.connection.user
      password            = local.connection.password
      host                = local.connection.host
      port                = local.connection.port
      timeout             = local.connection.timeout
      script_path         = local.connection.script_path
      private_key         = local.connection.private_key
      certificate         = local.connection.certificate
      agent               = local.connection.agent
      agent_identity      = local.connection.agent_identity
      host_key            = local.connection.host_key
      bastion_host        = local.connection.bastion_host
      bastion_host_key    = local.connection.bastion_host_key
      bastion_port        = local.connection.bastion_port
      bastion_user        = local.connection.bastion_user
      bastion_password    = local.connection.bastion_password
      bastion_private_key = local.connection.bastion_private_key
      bastion_certificate = local.connection.bastion_certificate
    }

  }
  # only deliver the archive if the archive has been updated
  count = var.skip_archive_push || (var.skip == true) ? 0 : 1
  triggers = {
    #run = var.skip == true ? 0 : timestamp()
    run = var.skip == true ? 0 : element(null_resource.chef_export.*.id, 0)
  }
}

locals {
  _destination_for_supplied_archive = format(
    "%s/%s",
    local.target_export_dir,
    local.supplied_policyfile_archive_basename
  )
}

resource "null_resource" "untar_archive" {
  depends_on = [null_resource.chef_export, null_resource.deliver_archive]
  provisioner "remote-exec" {

    connection {
      type                = local.connection.type
      user                = local.connection.user
      password            = local.connection.password
      host                = local.connection.host
      port                = local.connection.port
      timeout             = local.connection.timeout
      script_path         = local.connection.script_path
      private_key         = local.connection.private_key
      certificate         = local.connection.certificate
      agent               = local.connection.agent
      agent_identity      = local.connection.agent_identity
      host_key            = local.connection.host_key
      bastion_host        = local.connection.bastion_host
      bastion_host_key    = local.connection.bastion_host_key
      bastion_port        = local.connection.bastion_port
      bastion_user        = local.connection.bastion_user
      bastion_password    = local.connection.bastion_password
      bastion_private_key = local.connection.bastion_private_key
      bastion_certificate = local.connection.bastion_certificate
    }


    inline = [
      format("echo '🎒 unpacking %s to %s'",
        local._archive_supplied ? local._destination_for_supplied_archive : format(
          "%s/%s",
          local.target_export_dir,
          basename(trimsuffix(trimspace(replace(file(
            format(
              "%s/%s-%s.chef_export.out",
              local.local_build_dir,
              local.policy_name,
              lookup(
                regex("(?ms:(?:(?:^Policy revision id: ){1}(?P<policy_revision>[a-z0-9A-Z]{64}$)))",
                  file(
                    format("%s/%s-%s.chef_update.out",
                      local.local_build_dir,
                      local.policy_name,
                      filesha256(local.policyfile)
                    )
                  )
                ),
                "policy_revision",
              )
              ,
            )
          ), "/Exported policy .* to /", "")), "/"))
        ),
        local.target_src_dir,
      ),
      format("rm -rf %s/*", local.target_src_dir),
      format(
        "tar --exclude-vcs-ignores --extract --verbose --file %s --directory %s",
        local._archive_supplied ? local._destination_for_supplied_archive : format(
          "%s/%s",
          local.target_export_dir,
          basename(trimsuffix(trimspace(replace(file(
            format(
              "%s/%s-%s.chef_export.out",
              local.local_build_dir,
              local.policy_name,
              lookup(
                regex("(?ms:(?:(?:^Policy revision id: ){1}(?P<policy_revision>[a-z0-9A-Z]{64}$)))",
                  file(
                    format("%s/%s-%s.chef_update.out",
                      local.local_build_dir,
                      local.policy_name,
                      filesha256(local.policyfile)
                    )
                  )
                ),
                "policy_revision",
              )
              ,
            )
          ), "/Exported policy .* to /", "")), "/"))
        ),
        local.target_src_dir,
      ),
      format("ls %s", local.target_src_dir),
    ]
  }

  triggers = {
    run = var.skip == true ? 0 : try(element(null_resource.deliver_archive.*.id, 0), 1)
  }
}

resource "null_resource" "deliver_attributes_file" {
  depends_on = [null_resource.untar_archive]
  provisioner "file" {
    source      = trimsuffix(local.attributes_file_source, "/")
    destination = format("%s/%s", local.target_src_dir, local.attributes_file_basename)

    connection {
      type                = local.connection.type
      user                = local.connection.user
      password            = local.connection.password
      host                = local.connection.host
      port                = local.connection.port
      timeout             = local.connection.timeout
      script_path         = local.connection.script_path
      private_key         = local.connection.private_key
      certificate         = local.connection.certificate
      agent               = local.connection.agent
      agent_identity      = local.connection.agent_identity
      host_key            = local.connection.host_key
      bastion_host        = local.connection.bastion_host
      bastion_host_key    = local.connection.bastion_host_key
      bastion_port        = local.connection.bastion_port
      bastion_user        = local.connection.bastion_user
      bastion_password    = local.connection.bastion_password
      bastion_private_key = local.connection.bastion_private_key
      bastion_certificate = local.connection.bastion_certificate
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
      type                = local.connection.type
      user                = local.connection.user
      password            = local.connection.password
      host                = local.connection.host
      port                = local.connection.port
      timeout             = local.connection.timeout
      script_path         = local.connection.script_path
      private_key         = local.connection.private_key
      certificate         = local.connection.certificate
      agent               = local.connection.agent
      agent_identity      = local.connection.agent_identity
      host_key            = local.connection.host_key
      bastion_host        = local.connection.bastion_host
      bastion_host_key    = local.connection.bastion_host_key
      bastion_port        = local.connection.bastion_port
      bastion_user        = local.connection.bastion_user
      bastion_password    = local.connection.bastion_password
      bastion_private_key = local.connection.bastion_private_key
      bastion_certificate = local.connection.bastion_certificate
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

resource "null_resource" "deliver_chef_installer_script" {
  depends_on = [null_resource.create_target_dirs]

  provisioner "file" {
    source      = local._install_chef_script_source
    destination = local._install_chef_script_destination

    connection {
      type                = local.connection.type
      user                = local.connection.user
      password            = local.connection.password
      host                = local.connection.host
      port                = local.connection.port
      timeout             = local.connection.timeout
      script_path         = local.connection.script_path
      private_key         = local.connection.private_key
      certificate         = local.connection.certificate
      agent               = local.connection.agent
      agent_identity      = local.connection.agent_identity
      host_key            = local.connection.host_key
      bastion_host        = local.connection.bastion_host
      bastion_host_key    = local.connection.bastion_host_key
      bastion_port        = local.connection.bastion_port
      bastion_user        = local.connection.bastion_user
      bastion_password    = local.connection.bastion_password
      bastion_private_key = local.connection.bastion_private_key
      bastion_certificate = local.connection.bastion_certificate
    }
  }
  # only deliver the installer script if the file has been changed
  count = var.skip == true ? 0 : 1
  # only deliver the installer script if the file has been changed
  triggers = {
    script_hash = filesha256(local._install_chef_script_source)
  }
}

locals {
  ensure_chef_vars = {
    target_install_dir  = local.target_install_dir,
    chef_client_version = local.chef_client_version,
  }
  ensure_chef_content = templatefile(
    "${path.module}/scripts/ensurechef.sh.tmpl",
    tomap(local.ensure_chef_vars)
  )
}


resource "null_resource" "deliver_ensure_chef_script" {
  depends_on = [null_resource.create_target_dirs, null_resource.deliver_chef_installer_script]
  # only deliver the ensure/installer script if the file has been changed
  count = var.skip == true ? 0 : 1

  provisioner "file" {
    content     = local.ensure_chef_content
    destination = format("%s/ensurechef.sh", local.target_install_dir)

    connection {
      type                = local.connection.type
      user                = local.connection.user
      password            = local.connection.password
      host                = local.connection.host
      port                = local.connection.port
      timeout             = local.connection.timeout
      script_path         = local.connection.script_path
      private_key         = local.connection.private_key
      certificate         = local.connection.certificate
      agent               = local.connection.agent
      agent_identity      = local.connection.agent_identity
      host_key            = local.connection.host_key
      bastion_host        = local.connection.bastion_host
      bastion_host_key    = local.connection.bastion_host_key
      bastion_port        = local.connection.bastion_port
      bastion_user        = local.connection.bastion_user
      bastion_password    = local.connection.bastion_password
      bastion_private_key = local.connection.bastion_private_key
      bastion_certificate = local.connection.bastion_certificate
    }

  }

  provisioner "remote-exec" {

    connection {
      type                = local.connection.type
      user                = local.connection.user
      password            = local.connection.password
      host                = local.connection.host
      port                = local.connection.port
      timeout             = local.connection.timeout
      script_path         = local.connection.script_path
      private_key         = local.connection.private_key
      certificate         = local.connection.certificate
      agent               = local.connection.agent
      agent_identity      = local.connection.agent_identity
      host_key            = local.connection.host_key
      bastion_host        = local.connection.bastion_host
      bastion_host_key    = local.connection.bastion_host_key
      bastion_port        = local.connection.bastion_port
      bastion_user        = local.connection.bastion_user
      bastion_password    = local.connection.bastion_password
      bastion_private_key = local.connection.bastion_private_key
      bastion_certificate = local.connection.bastion_certificate
    }

    inline = [
      format("chmod +x %s/ensurechef.sh", local.target_install_dir),
    ]
  }

  triggers = {
    script_hash = sha256(local.ensure_chef_content)
  }
}


resource "null_resource" "ensure_chef_client" {
  depends_on = [null_resource.deliver_ensure_chef_script]
  provisioner "remote-exec" {

    connection {
      type                = local.connection.type
      user                = local.connection.user
      password            = local.connection.password
      host                = local.connection.host
      port                = local.connection.port
      timeout             = local.connection.timeout
      script_path         = local.connection.script_path
      private_key         = local.connection.private_key
      certificate         = local.connection.certificate
      agent               = local.connection.agent
      agent_identity      = local.connection.agent_identity
      host_key            = local.connection.host_key
      bastion_host        = local.connection.bastion_host
      bastion_host_key    = local.connection.bastion_host_key
      bastion_port        = local.connection.bastion_port
      bastion_user        = local.connection.bastion_user
      bastion_password    = local.connection.bastion_password
      bastion_private_key = local.connection.bastion_private_key
      bastion_certificate = local.connection.bastion_certificate
    }

    inline = [
      format("/bin/bash %s/ensurechef.sh", local.target_install_dir),
    ]
  }

  count = var.skip == true ? 0 : 1

  triggers = {
    # only re-run if client version changed
    chef_client_version = local.chef_client_version
  }

}

resource "null_resource" "chef_client_run" {
  depends_on = [
    null_resource.untar_archive,
    null_resource.ensure_chef_client,
    null_resource.deliver_attributes_file,
    null_resource.deliver_data_bags
  ]
  provisioner "remote-exec" {

    connection {
      type                = local.connection.type
      user                = local.connection.user
      password            = local.connection.password
      host                = local.connection.host
      port                = local.connection.port
      timeout             = local.connection.timeout
      script_path         = local.connection.script_path
      private_key         = local.connection.private_key
      certificate         = local.connection.certificate
      agent               = local.connection.agent
      agent_identity      = local.connection.agent_identity
      host_key            = local.connection.host_key
      bastion_host        = local.connection.bastion_host
      bastion_host_key    = local.connection.bastion_host_key
      bastion_port        = local.connection.bastion_port
      bastion_user        = local.connection.bastion_user
      bastion_password    = local.connection.bastion_password
      bastion_private_key = local.connection.bastion_private_key
      bastion_certificate = local.connection.bastion_certificate
    }

    inline = [
      format(
        "cd %s",
        local.target_src_dir,
      ),
      "chef-client --version",
      "pwd",
      format(
        "sudo chef-client --always-dump-stacktrace --once --log_level %s --local-mode --chef-license accept %s 2>&1 | tee %s",
        local.chef_client_log_level,
        local.json_attributes,
        local.chef_client_logfile,
      )
    ]
  }

  triggers = {
    run = var.skip == true ? 0 : timestamp()
  }

}
