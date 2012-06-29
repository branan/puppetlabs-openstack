step "Openstack: deploy an openstack-all on a master"

masters = hosts.select { |host| host['roles'].include? 'master' }

masters.each do |host|

  if host.is_pe?
    modulepath = '/etc/puppetlabs/puppet/modules'
  else
    modulepath = '/etc/puppet/modules'
  end

  host['roles'].select { |r| r =~ /openstack/ }.each do |role|
    on host, "puppet apply --certname=#{role} #{modulepath}/openstack/examples/site.pp"
  end
end
