# PACKAGE NAME
$package_name         = 'prv.iaas.web.tomcat85'

# CONST
$temp                     = '/tmp'

# BINARY FILES
$tomcat85_file         = 'apache-tomcat-7.0.99.tar.gz'
$java_file             = 'jdk-8u101-linux-x64.tar.gz'

# MAIN
notice("$package_name installation in progress")

file {'temp_download':
  path    => $temp,
  ensure  => directory,
}

$tar_cmd1 = "/bin/tar -xvf ${temp}/${java_file} -C ${temp}"
exec{'untar1':
command => $tar_cmd1,
require => File['temp_download']
}

file_line{'addline':
path => '/etc/profile',
after => '# and Bourne compatible shells (bash(1), ksh(1), ash(1), ...).',
line => 'JAVA_HOME=/tmp/jdk1.8.0_101
PATH=$PATH:$HOME/bin:$JAVA_HOME/bin
export JAVA_HOME
export PATH',
require => Exec['untar1']
}

file{'mode':
path => '/etc/profile',
ensure => 'file',
mode => '744',
require => File_line['addline']
}

exec{'exec_profile':
command => '/etc/profile',
require => File['mode']
}

exec{'F_install':
command => '/usr/bin/update-alternatives --install "/usr/bin/java" "java" "/tmp/jdk1.8.0_101/bin/java" 1',
require => Exec['exec_profile']
}

exec{'S_install':
command => '/usr/bin/update-alternatives --install "/usr/bin/javac" "javac" "/tmp/jdk1.8.0_101/bin/javac" 1',
require => Exec['F_install']
}

exec{'T_install':
command => '/usr/bin/update-alternatives --install "/usr/bin/javaws" "javaws" "/tmp/jdk1.8.0_101/bin/javaws" 1',
require => Exec['S_install']
}

exec{'F_update':
command => '/usr/bin/update-alternatives --set java /tmp/jdk1.8.0_101/bin/java',
require => Exec['T_install']
}

exec{'S_update':
command => '/usr/bin/update-alternatives --set javac /tmp/jdk1.8.0_101/bin/javac',
require => Exec['F_update']
}

exec{'T_update':
command => '/usr/bin/update-alternatives --set javaws /tmp/jdk1.8.0_101/bin/javaws',
require => Exec['S_update']
}

exec {'Update':
  command => '/usr/bin/apt update',
  provider => shell,
  require => File['temp_download']
}



exec {'Add_Tomcat_user':
  command => 'useradd -m -U -d /opt/tomcat -s /bin/false tomcat',
  provider => shell,
  require => Exec['Update']
}

exec {'New_Directory':
        command => '/bin/mkdir -p /opt/tomcat',
        provider => shell,
        require => Exec['Add_Tomcat_user']
}
# Unzipping File

$tar_cmd = "/bin/tar xf ${temp}/${tomcat85_file} -C /opt/tomcat"

exec {'untar':
  command     => $tar_cmd,
  require => Exec['New_Directory']
}

file {'/opt/tomcat/latest':
        ensure => 'link',
        target => '/opt/tomcat/apache-tomcat-7.0.99',
        require => Exec['untar'],
}

exec {'change_own':
        command => 'chown -R tomcat: /opt/tomcat',
        provider => shell,
        require => File['/opt/tomcat/latest']
}

exec {'Bash':
        command => "sh -c 'chmod +x /opt/tomcat/latest/bin/*.sh'",
        provider => shell,
        require => Exec['change_own']
}

file { '/etc/systemd/system/tomcat.service':
  ensure  => 'present',
  replace => 'no',
  require => Exec['Bash'],
  content =>
'[Unit]
Description=Tomcat 7.0 servlet container
After=network.target

[Service]
Type=forking

User=tomcat
Group=tomcat

Environment="CATALINA_BASE=/opt/tomcat/latest"
Environment="CATALINA_HOME=/opt/tomcat/latest"
Environment="CATALINA_PID=/opt/tomcat/latest/temp/tomcat.pid"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"

ExecStart=/opt/tomcat/latest/bin/startup.sh
ExecStop=/opt/tomcat/latest/bin/shutdown.sh

[Install]
WantedBy=multi-user.target',
}

exec {'notify':
  command => '/bin/systemctl daemon-reload',
  require => File['/etc/systemd/system/tomcat.service'],
}

service { 'tomcat':
  name => (tomcat),
  ensure    => running,
  enable    => true,
  require   => Exec['notify']
}
