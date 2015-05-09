#
#
#
Exec {
  path => '/usr/local/bin:/usr/bin:/usr/sbin:/bin'
}

# set defaults for file ownership/permissions
File {
  owner => 'root',
  group => 'root',
  mode => '0644',
}

### We don't need the chef-client.
service {'chef-client':
  ensure   => stopped,
}

#
class { 'timezone':
  timezone => 'Europe/Paris',
} -> class { '::ntp':
  restrict => ['127.0.0.1'],
}

# ClouderaManager node
node /^cm\d+.vagrant.dev$/ {

  class { 'cloudera':
    cm_server_host   => $::hostname,
    install_cmserver => true,
  }
}
