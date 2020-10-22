name 'chef_client'
default_source :supermarket
cookbook 'chef-client', '~> 11.5.0', :supermarket
run_list 'chef-client::default'
