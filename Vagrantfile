# -*- mode: ruby -*-
# vi: set ft=ruby :

vm_ip                  = "172.94.43.196"
host_name              = "ckan.lo"
digitalocean_host_name = "ckan.do"

WINDOWS = (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/) ? true : false
vagrant_dir = File.dirname(__FILE__) + "/"

def chef(config, provider, hostname)
  config.vm.provision :chef_solo do |chef|

    chef.cookbooks_path = "cookbooks"
    # chef debug level, start vagrant like this to debug:
    # $ CHEF_LOG_LEVEL=debug vagrant <provision or up>
    chef.log_level = ENV['CHEF_LOG'] || "info"

    # chef recipes/roles
    chef.add_recipe("vagrant")

    chef.json = {
      :host_name => hostname,
      :user => "vagrant",
      :repository => "https://github.com/ckan/ckan.git",
      :provider => provider,
    }
  end
end

Vagrant.configure("2") do |config|

  config.vm.provider :virtualbox do |provider, config|
    config.vm.box = "precise64"
    config.vm.box_url = "http://files.vagrantup.com/precise64.box"
    config.vm.synced_folder ".", "/vagrant", :nfs => !WINDOWS

    provider.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root", "1"]

    config.vm.network :private_network, ip: vm_ip
    config.vm.hostname = host_name

    chef(config, "virtualbox", host_name)
  end

# To configure a digital ocean provider, uncomment the following
=begin
  config.vm.provider :digital_ocean do |provider, config|
    Vagrant.require_plugin('vagrant-digitalocean')
    Vagrant.require_plugin('vagrant-omnibus')

    config.ssh.username = 'vagrant'
    config.ssh.private_key_path = vagrant_dir + 'cookbooks/vagrant/templates/default/vagrant'
    config.vm.box = 'digital_ocean'
    config.vm.box_url = "https://github.com/smdahlen/vagrant-digitalocean/raw/master/box/digital_ocean.box"
    config.vm.hostname = digitalocean_host_name
    config.omnibus.chef_version = :latest

    data = JSON.parse(IO.read(vagrant_dir + 'digitalocean.json'))
    provider.client_id = data['client_id']
    provider.api_key = data['api_key']
    provider.image = 'Ubuntu 12.04 x64'
    provider.region = 'Amsterdam 2'
    provider.size = '1GB'

    chef(config, "digitalocean", digitalocean_host_name)
  end
=end
end
