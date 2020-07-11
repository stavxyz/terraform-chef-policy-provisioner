name 'default'

default_source :supermarket

cookbook 'managed_chef_server', '= 0.18.1', :supermarket

run_list 'managed_chef_server::default', 'managed_chef_server::managed_organization'


named_run_list :install, "managed_chef_server::default"
named_run_list :upgrade, "managed_chef_server::upgrade"

default['chef-server']['accept_license'] = true

# managed organization for Chef-managed server
default['mcs']['org']['name'] = 'example'
default['mcs']['org']['full_name'] = 'Your Chef Managed Organization'
default['mcs']['managed_user']['email'] = 'you@example.com'
