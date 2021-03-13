name 'mongodb'
default_source :supermarket
cookbook 'sc-mongodb', '~> 4.1.0', :supermarket
run_list 'sc-mongodb::default'
