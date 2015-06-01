# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/trusty64"
#  config.vm.box = "puppetlabs/centos-6.6-64-puppet"
  config.ssh.forward_agent = true

  # Configure plugins
  unless ENV["VAGRANT_NO_PLUGINS"]

    required_plugins = %w( vagrant-cachier landrush vagrant-hostmanager)
    required_plugins.each do |plugin|
      system "vagrant plugin install #{plugin}" unless Vagrant.has_plugin? plugin
    end

    # Use landrush to manage DNS entries
    # Check status with : vagrant landrush status
    if Vagrant.has_plugin?("landrush")
      config.landrush.enabled = true
    end
    if Vagrant.has_plugin?("vagrant-hostmanager")
      config.hostmanager.enabled = true
    end

    # Need nfs-kernel-server system package on debian/ubuntu host
    if Vagrant.has_plugin?("vagrant-cachier")
      config.cache.scope = :box
#      config.cache.synced_folder_opts = {
#        type: :nfs,
        # The nolock option can be useful for an NFSv3 client that wants to avoid the
        # NLM sideband protocol. Without this option, apt-get might hang if it tries
        # to lock files needed for /var/cache/* operations. All of this can be avoided
        # by using NFSv4 everywhere. Please note that the tcp option is not the default.
#        mount_options: ['rw', 'vers=3', 'tcp', 'nolock']
#      }
    end
  end

  config.vm.synced_folder "puppet/files", "/etc/puppet/files"

  (1..3).each do |i|
    config.vm.define "node#{i}" do |node|
      node.vm.hostname = "node#{i}.vagrant.dev"
      node.vm.network :private_network, ip: "192.168.65.#{i+10}"
      node.vm.network :forwarded_port, guest: 2181, host: "218#{1 + (i - 1)}"
      node.vm.provider :virtualbox do |vb|
        vb.gui = false
        vb.memory = '2048'
        vb.customize ["modifyvm", :id, "--cpuexecutioncap", "50"]
      end
    end
  end

  config.vm.provision :puppet do |puppet|
    puppet.manifests_path = "puppet/manifests"
    puppet.manifest_file = "site.pp"
    puppet.module_path = [ "puppet/modules", "puppet-contrib/modules"]
    puppet.hiera_config_path = "puppet/hiera.yaml"
    puppet.options="--fileserverconfig=/vagrant/puppet/fileserver.conf --verbose"

    ## custom facts provided to Puppet
    puppet.facter = {
      ## tells default.pp that we're running in Vagrant
      "is_vagrant" => true,
    }
  end
end
