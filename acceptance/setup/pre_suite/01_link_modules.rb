require 'yaml'

masters = hosts.select { |host| host['roles'].include? 'master' }
repo_hash = YAML.load_file(File.join(File.dirname(__FILE__), '..', '..', '..', 'other_repos.yaml'))
repos = (repo_hash['repos'] || {})
repos_to_clone = (repos['repo_paths'] || {})
modules = repos_to_clone.values
modules << "openstack"

step "Masters: link openstack modules into module path"

masters.each do |host|
  if host.is_pe?
    modulepath = '/etc/puppetlabs/puppet/modules'
  else
    modulepath = '/etc/puppet/modules'
  end

  on host, "mkdir -p #{modulepath}"

  modules.each do |mod|
    on host, "test -L #{modulepath}/#{mod} || ln -s /opt/puppet-git-repos/#{mod} #{modulepath}/#{mod}"
  end
end
