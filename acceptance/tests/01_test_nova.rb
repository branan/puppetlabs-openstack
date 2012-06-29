step "Run the test_nova.sh script"

masters = hosts.select { |host| host['roles'].include? 'master' }

test_machines = masters.select { |host| host['roles'].include? 'openstack_all' }
on test_machines, "bash /tmp/test_nova.sh"
