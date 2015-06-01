#
#
#
$CM_SERVER_HOST='node1.vagrant.dev'
$opentsdb_version = '2.1.0'

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

Firewall {
  before  => Class['fw::post'],
  require => Class['fw::pre'],
}

class { ['fw::pre', 'fw::post']: }

class { 'firewall': }

firewall { '100 allow ssh':
    chain   => 'INPUT',
    state   => ['NEW'],
    dport   => '22',
    proto   => 'tcp',
    action  => 'accept',
}  

# http://www.cloudera.com/content/cloudera/en/documentation/core/latest/topics/cdh_ig_ports_cdh5.html  
firewall { '101 allow cmf':
  action => accept,
  port   => [ 7180, 7182 ],
  proto  => tcp,
}->
firewall { '102 allow hbase':
  action => accept,
  port   => [ 2181, 60000, 60010, 60020, 60030  ],
  proto  => tcp,
}->
firewall { '103 allow zookeeper':
  action => accept,
  port   => [ 2181 ],
  proto  => tcp,
}->
firewall { '104 allow opentsdb':
  action => accept,
  port   => [ 4242 ],
  proto  => tcp,
}->
firewall { '105 allow hdfs':
  action => accept,
# Deprecated : 50470, 50475, 
  port   => [ 1004, 1006, 8020, 8022, 50010, 50020, 50070, 50075 ],
  proto  => tcp,
}

class { 'hadoop':
  hdfs_hostname => $::fqdn,
  yarn_hostname => $::fqdn,
  slaves => [ $::fqdn, "127.0.1.1", "127.0.0.1" ],
#  frontends => [ $::fqdn ],
  # security needs to be disabled explicitly by using empty string
  realm => '',
  properties => {
    'dfs.replication' => 1,
  },
  perform => false,
}

class { 'hbase':
  hdfs_hostname => $::fqdn,
  master_hostname => $::fqdn,
  zookeeper_hostnames => [ $::fqdn ],
  external_zookeeper => true,
  slaves => [ $::fqdn ],
  frontends => [ $::fqdn ],
  realm => '',
  features => {
    hbmanager => true,
  },
}

# node conf
node /^node1.vagrant.dev$/ {

  include stdlib

   # HDFS
  include hadoop::namenode
  # YARN
  include hadoop::resourcemanager
  # MAPRED
  include hadoop::historyserver
  # slave (HDFS)
  include hadoop::datanode
  # slave (YARN)
  include hadoop::nodemanager
  ## client
  #include hadoop::frontend

  include hbase::master
##  include hbase::zookeeper
  include hbase::regionserver
  include hbase::frontend
  include hbase::hdfs

  class{'site_hadoop':
    stage => setup,
  }

  class{'zookeeper':
    hostnames => [ $::fqdn ],
    realm => '',
  }

  Class['hadoop::namenode::service'] -> Class['hbase::hdfs']
  Class['hadoop::namenode::service'] -> Class['hbase::master::service']

  Class['hbase::master::service'] ->
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
        content  => 'JAVA_HOME="/usr/lib/jvm/java-7-openjdk-amd64"',
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
