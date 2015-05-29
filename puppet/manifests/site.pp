#
#
#
$CM_SERVER_HOST='cm1.vagrant.dev'

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

# Timezone stuff
class { 'timezone':
  timezone => 'Europe/Paris',
} -> class { '::ntp':
  restrict => ['127.0.0.1'],
}

# Firewall stuff
resources { 'firewall':
  purge => true
}

##Firewall {
##  before  => Class['fw::post'],
##  require => Class['fw::pre'],
##}
##
##class { ['fw::pre', 'fw::post']: }
##
##firewall { '100 allow ssh':
##    chain   => 'INPUT',
##    state   => ['NEW'],
##    dport   => '22',
##    proto   => 'tcp',
##    action  => 'accept',
##}  
##  
##firewall { '101 allow cmf':
##  action => accept,
##  port   => [ 7180, 7182 ],
##  proto  => tcp,
##}->
##firewall { '102 allow hbase':
##  action => accept,
##  #port   => [ 2181, 60000, 60010, 60020, 60030 ],
##  port   => [ 34033, 60000, 60010, 60020, 60030 ],
##  proto  => tcp,
##}->
##firewall { '103 allow zookeeper':
##  action => accept,
##  port   => [ 2181 ],
##  proto  => tcp,
##}
##firewall { '104 allow opentsdb':
##  action => accept,
##  port   => [ 4242 ],
##  proto  => tcp,
##}

# ClouderaManager node
node /^cm\d+.vagrant.dev$/ {

  if $::osfamily == 'Debian' {
    class { '::apt':
      apt_update_frequency => 'always',
    }
  }

  class { '::cloudera::cm5::repo': }->
  class { '::cloudera::java5': }->
  class { '::cloudera::cm5':
#    server_host => $CM_SERVER_HOST,
  }->
  class { '::cloudera::cm5::server': }

  class { '::cloudera::cdh5::repo': }->
  class { '::cloudera::cdh5::hbase': }->
  package { 'hbase-master':
    ensure => installed,
  }->
  service { 'hbase-master':
    ensure => running,
  }->
  service { 'opentsdb' :
    ensure     => running,
    hasrestart => true,
    require    => Exec ['opentsdb-init-hbase'],
  }

# OpenTSDB
  $opentsdb_version = '2.1.0'

  case $::osfamily {
    /Debian/ : {
      exec { 'opentsdb-pkg-download':
        command => "wget https://github.com/OpenTSDB/opentsdb/releases/download/v${opentsdb_version}/opentsdb-${opentsdb_version}_all.deb",
        creates => "/vagrant/opentsdb-${opentsdb_version}_all.deb",
        cwd     => '/vagrant',
        unless  => "test -f /vagrant/opentsdb-${opentsdb_version}_all.deb"
      }->
      package { 'opentsdb':
        provider => dpkg,
        ensure   => installed,
        source   => "/vagrant/opentsdb-${opentsdb_version}_all.deb",
      }->
      file { '/etc/default/opentsdb':
        ensure   => present,
        content  => 'JAVA_HOME="/usr/lib/jvm/java-7-oracle-cloudera"',
      } ->
      exec { 'opentsdb-fix-start-daemon':
        command => 'sed -ie \'s/--exec \/bin\/bash -- -c \"\(.*\)\"/--exec \/bin\/bash -- \1/\' /etc/init.d/opentsdb',
      }->
      exec { 'opentsdb-fix-start-path':
#        command => 'sed -ie \'s/export JAVA_HOME/. \/usr\/lib\/bigtop-utils\/bigtop-detect-javahome\nexport JAVA_HOME\nPATH=${PATH}:${JAVA_HOME}\/bin/\' /etc/init.d/opentsdb',
        command => 'sed -ie \'s/export JAVA_HOME/export JAVA_HOME\nPATH=${PATH}:${JAVA_HOME}\/bin/\' /etc/init.d/opentsdb',
      }->
      exec { 'opentsdb-init-hbase':
        command => 'bash -c ". /usr/lib/bigtop-utils/bigtop-detect-javahome && env COMPRESSION=NONE HBASE_HOME=/usr/lib/hbase /usr/share/opentsdb/tools/create_table.sh"',
        timeout => 0,
        require => Service['hbase-master'],
      }
        
    }
    default : {
      notify { "${::osfamily} is not yet supported": }
    }
  }
  
}
