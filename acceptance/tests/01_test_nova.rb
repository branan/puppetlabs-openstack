def nova_vm_info(hosts, vm_name, &block)
  on hosts, "bash -c 'source /root/openrc; nova show #{vm_name}'" do
    vm_info = {}
    lines = []
    result.output.lines.each { |l| lines << l }
    lines[3, lines.length-4].each do |line|
      parts = line.split('|').map! { |f| f.strip }
      vm_info[parts[1].strip()] = parts[2].strip()
    end
    yield vm_info
  end
end


masters = hosts.select { |host| host['roles'].include? 'master' }
test_machines = masters.select { |host| host['roles'].include? 'openstack_all' }

step "Fetch the cirros image"
image_name = "cirros-0.3.0-i386-disk.img"
image_uri = "https://launchpad.net/cirros/trunk/0.3.0/+download/#{image_name}"
on test_machines, "wget #{image_uri} -O /tmp/#{image_name}"

step "Load the cirros image into glance"
on test_machines, "bash -c 'source /root/openrc; glance add name=cirros is_public=true container_format=bare disk_format=qcow2' < /tmp/#{image_name}"

on test_machines, "bash -c 'source /root/openrc; glance index | grep cirros | head -1'" do
  $image_id = result.output.split(' ')[0]
end

step "Generate a keypair for Nova"
on test_machines, "ssh-keygen -f /tmp/id_rsa -t rsa -N ''"
on test_machines, "bash -c 'source /root/openrc; nova keypair-add --pub_key /tmp/id_rsa.pub key_cirros'"

step "Create and populate a security group"
on test_machines, "bash -c 'source /root/openrc; nova secgroup-create cirros cirros'"
on test_machines, "bash -c 'source /root/openrc; nova secgroup-add-rule cirros tcp 22 22 0.0.0.0/0'"
on test_machines, "bash -c 'source /root/openrc; nova secgroup-add-rule cirros icmp -1 -1 0.0.0.0/0'"

step "Launch an instance in Nova"
on test_machines, "bash -c 'source /root/openrc; nova boot --flavor 1 --image #{$image_id} --key_name key_cirros --security_groups cirros test_vm'"

step "Wait for the VM to become ready"
$booted = false
while ! $booted
  nova_vm_info(test_machines, 'test_vm') do |vm_info|
    if vm_info['OS-EXT-STS:vm_state'].downcase == "active"
      $booted = true
      $instance_ip = vm_info['novanetwork network']
    elsif vm_info['OS-EXT-STS:vm_state'].downcase == "error"
      fail_test "VM failed to boot properly"
    end
  end
  sleep 1
end

step "Give the OS a chance to launch"
sleep 50

step "Connect to the running VM"
on test_machines, "ssh cirros@#{$instance_ip} -i /tmp/id_rsa -o 'StrictHostKeyChecking=no' -o 'UserKnownHostsFile=/dev/null' echo 'test completed successfully'"

step "cleanup"
on test_machines, "rm /tmp/id_rsa{,.pub}"
on test_machines, "bash -c 'source /root/openrc; nova delete test_vm'"
on test_machines, "bash -c 'source /root/openrc; nova keypair-delete key_cirros'"
on test_machines, "bash -c 'source /root/openrc; glance delete -f `glance index | grep cirros | cut -d\" \" -f1`'"
sleep 3 # give the VM time to shutdown before we delete the secgroup
on test_machines, "bash -c 'source /root/openrc; nova secgroup-delete cirros'"
