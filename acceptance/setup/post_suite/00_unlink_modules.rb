require 'yaml'

masters = hosts.select { |host| host['roles'].include? 'master' }
repo_hash = YAML.load_file(File.join(File.dirname(__FILE__), '..', '..', '..', 'other_repos.yaml'))
repos = (repo_hash['repos'] || {})
repos_to_clone = (repos['repo_paths'] || {})
modules = repos_to_clone.values

step "Masters: unlink openstack modules from module path"

masters.each do |host|
  if host.is_pe?
    modulepath = '/etc/puppetlabs/puppet/modules'
  else
    modulepath = '/etc/puppet/modules'
  end

  modules.each do |mod|
    on masters, "rm #{modulepath}/#{mod}"
  end
end
