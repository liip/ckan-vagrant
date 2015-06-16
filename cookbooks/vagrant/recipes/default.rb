USER = node[:user]
REPOSITORY = node[:repository]
HOME = "/home/#{USER}"
SOURCE_DIR = "#{HOME}/pyenv/src"
CKAN_DIR = "#{SOURCE_DIR}/ckan"
VAGRANT_DIR = "/vagrant"
PROVIDER = node[:provider]
RUN_TESTS = false
RUN_HARVESTER = false

bash "set default locale to UTF-8" do
  not_if "locale | grep 'LC_ALL=en_US.UTF-8'"
  code <<-EOH
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
dpkg-reconfigure locales
EOH
end

execute "apt-get update"

# install the software we need
%w(
openjdk-6-jre-headless
curl
tmux
vim
git
libapache2-mod-wsgi
libpq5
libpq-dev
postgresql
solr-jetty
unzip
python-pip
python-dev
python-virtualenv
python-pastescript
python-software-properties
rabbitmq-server
libxml2-dev
libxslt-dev
).each { | pkg | package pkg }

template "/home/vagrant/.bash_aliases" do
  user "vagrant"
  mode "0644"
  source ".bash_aliases.erb"
end

template "/etc/apache2/sites-available/vhost.conf" do
  user "root"
  mode "0644"
  source "vhost.conf.erb"
  notifies :reload, "service[apache2]"
end

service "apache2" do
  supports :restart => true, :reload => true, :status => true
  action [ :enable, :start ]
end

template "/etc/default/jetty" do
  mode "0644"
  source "jetty"
end

bash "create virtualenv" do
  user "vagrant"
  not_if "test -f /home/#{USER}/pyenv/bin/activate"
  code <<-EOH
virtualenv --no-site-packages /home/#{USER}/pyenv
EOH
end

# Create source dir
directory SOURCE_DIR do
  owner USER
  group USER
end

bash "clone ckan" do
  user USER
  group USER
  not_if "test -f #{CKAN_DIR}/README.rst"
  code <<-EOH
  git clone #{REPOSITORY} -b ckan-2.3 #{CKAN_DIR}
  cd #{CKAN_DIR}
  git submodule update --init
EOH
end

service "jetty" do
  supports :restart => true, :reload => true, :status => true
  action [ :enable, :start ]
end

src  = "#{CKAN_DIR}/ckanext/multilingual/solr/"
dest = "/etc/solr/conf/"
[
 "schema.xml",
 "english_stop.txt",
 "fr_elision.txt",
 "french_stop.txt",
 "german_stop.txt",
 "italian_stop.txt",
 "dutch_stop.txt",
 "greek_stopwords.txt",
 "polish_stop.txt",
 "portuguese_stop.txt",
 "romanian_stop.txt",
 "spanish_stop.txt"
].each do |file|
  link dest + file do
    to src + file
    notifies :restart, "service[jetty]", :immediately
  end
end

bash "make sure postgres is using UTF-8" do
  user "root"
  not_if "sudo -u postgres psql -c '\\l' | grep UTF8"
  code <<-EOH
service apache2 stop
pg_dropcluster --stop 9.1 main
pg_createcluster --start -e UTF-8 9.1 main
EOH
  notifies :restart, "service[apache2]"
end

execute "disable the apache default" do
  command "a2dissite default"
  notifies :reload, "service[apache2]"
end

# copy the development.ini
template "#{CKAN_DIR}/development.ini" do
  user USER
  mode 0644
  source "development.ini"
end

bash "install the ckan pip package" do
  user USER
  code <<-EOH
source #{HOME}/pyenv/bin/activate
cd #{CKAN_DIR}
pip install #{CKAN_DIR} --exists-action=i -e #{CKAN_DIR}
EOH
end

bash "install the ckan pip dependencies" do
  user USER
  code <<-EOH
source #{HOME}/pyenv/bin/activate
pip install -r #{CKAN_DIR}/requirements.txt
EOH
end

execute "enable vhost.conf within apache" do
  not_if "stat /etc/apache2/sites-enabled/vhost.conf"
  notifies :reload, "service[apache2]"
  command "a2ensite vhost.conf"
end

template "/etc/apache2/ports.conf" do
  owner "root"
  group "root"
  mode "0644"
  source "ports.conf"
  notifies :restart, "service[apache2]"
end

execute "create etc/ckan/default folder" do
  not_if "stat /etc/ckan/default"
  command "mkdir -p /etc/ckan/default"
end

template "/etc/ckan/default/apache.wsgi" do
  owner "root"
  group "root"
  mode "0644"
  source "apache.wsgi"
end

template "/etc/ckan/default/who.ini" do
  owner "root"
  group "root"
  mode "0644"
  source "who.ini"
  notifies :reload, "service[apache2]"
end

bash "create etc/cron.daily folder" do
  user "root"
  group "root"
  code <<-EOH
mkdir -p /etc/cron.daily
EOH
end

template "/etc/cron.daily/remove_old_sessions" do
  owner "root"
  group "root"
  mode "0644"
  source "remove_old_sessions.cronjob"
end

execute "make sure /home/vagrant/bin exists" do
  user "vagrant"
  command "mkdir -p /home/vagrant/bin"
end

template "/home/vagrant/bin/ckan" do
  owner "vagrant"
  group "vagrant"
  mode "0744"
  source "bin_ckan"
end

execute "make sure /home/vagrant/lib exists" do
  user "vagrant"
  command "mkdir -p /home/vagrant/lib"
end

bash "setup postgres db for ckan" do
  user "postgres"
  not_if "psql -l | grep ckan_default", :user => 'postgres'
  code <<-EOH
createuser -S -D -R ckan_default
psql -c "ALTER USER ckan_default with password 'pass'"
createdb -O ckan_default ckan_default -E utf-8
EOH
end

bash "install the ckan pip dev dependencies" do
  user USER
  code <<-EOH
source #{HOME}/pyenv/bin/activate
pip install -r #{CKAN_DIR}/dev-requirements.txt
EOH
end

service "rabbitmq-server" do
  supports :restart => true, :status => true
  action [ :enable, :start ]
end

# solely for development
# open http://sfa.lo:55672/ with guest/guest
execute "enabling the rabbitmq management console" do
  not_if "/usr/lib/rabbitmq/lib/rabbitmq_server-2.7.1/sbin/rabbitmq-plugins -m -E list | grep rabbitmq_management"
  command "/usr/lib/rabbitmq/lib/rabbitmq_server-2.7.1/sbin/rabbitmq-plugins enable rabbitmq_management"
  notifies :restart, "service[rabbitmq-server]"
end

#################################################################
#
# EXTENSION BLOCK
#
bash "Install the harvest extension" do
  user USER
  cwd VAGRANT_DIR
  code <<-EOH
  source #{HOME}/pyenv/bin/activate
  pip install -e git+https://github.com/okfn/ckanext-harvest.git@stable#egg=ckanext-harvest --src #{VAGRANT_DIR}
  cd #{VAGRANT_DIR}/ckanext-harvest
  python setup.py develop
  EOH
end

bash "Installing the ckan-harvest requirements" do
  user USER
  cwd "#{VAGRANT_DIR}/ckanext-harvest"
  code <<-EOH
  source #{HOME}/pyenv/bin/activate
  pip install -r pip-requirements.txt
  EOH
end

# Install custom extensions
# Put one custom extension on each line inside the %w()
%w().each do | ckan_ext |
    bash "Clone #{ckan_ext}" do
      user USER
      not_if "test -d #{VAGRANT_DIR}/#{ckan_ext}"
      cwd VAGRANT_DIR
      code <<-EOH
      source #{HOME}/pyenv/bin/activate
      pip install -e git+https://github.com/openresearchdata/#{ckan_ext}.git#egg=#{ckan_ext} --src #{VAGRANT_DIR}
      EOH
    end

    bash "Update #{ckan_ext}" do
      user USER
      only_if "git branch | grep '* master'"
      cwd "#{VAGRANT_DIR}/#{ckan_ext}"
      code <<-EOH
      GIT_SSL_NO_VERIFY=true git pull origin master
      EOH
    end

    bash "Install #{ckan_ext}" do
      user USER
      cwd VAGRANT_DIR
      code <<-EOH
      source #{HOME}/pyenv/bin/activate
      cd #{VAGRANT_DIR}/#{ckan_ext}
      python setup.py develop
      if test -e pip-requirements.txt; then
          pip install -r pip-requirements.txt
      fi
      if test -e requirements.txt; then
          pip install -r requirements.txt
      fi
      EOH
    end
end

#################################################################

# Generate database
bash "create database tables" do
  user USER
  cwd CKAN_DIR
  code <<-EOH
source #{HOME}/pyenv/bin/activate
paster --plugin=ckan db init
EOH
end

bash "creating folders necessary for ckan" do
  user "root"
  not_if "stat #{HOME}/filestore"
  code <<-EOH
mkdir -p #{HOME}/filestore
chown vagrant #{HOME}/filestore
chmod u+rw #{HOME}/filestore
EOH
  notifies :restart, "service[apache2]"
end

bash "creating an admin user" do
  user USER
  cwd CKAN_DIR
  not_if "sudo -u postgres psql -d ckan_default -c 'select * from #{'"'}user#{'"'}' | grep admin@email.org"
  code <<-EOH
  source #{HOME}/pyenv/bin/activate
  paster --plugin=ckan user add admin email=admin@email.org password=pass -c development.ini
  paster --plugin=ckan sysadmin add admin -c development.ini
  EOH
end

# if harvest is not sysadmin -> it'll not be able to create term_translation entries
bash "creating a harvest user" do
  user USER
  cwd CKAN_DIR
  not_if "sudo -u postgres psql -d ckan_default -c 'select * from #{'"'}user#{'"'}' | grep harvest@email.org"
  code <<-EOH
  source #{HOME}/pyenv/bin/activate
  paster --plugin=ckan user add harvest email=harvest@email.org password=pass -c development.ini
  paster --plugin=ckan sysadmin add harvest -c development.ini
  EOH
end

# Set up harvesters
# Put one harvester on each line inside the %w()
%w().each do | harvester |

  %w(gather fetch).each do | type |

    template "/etc/init/#{harvester}-#{type}.conf" do
      mode "0644"
      source "harvester.conf"
      variables({
                 :type => type,
                 :harvester => harvester,
                 :command => "harvester",
                 :ckan_dir => CKAN_DIR,
                 :home => HOME
               })
    end
  end

  bash "add source for the harvester #{harvester}" do
    user USER
    cwd CKAN_DIR
    code <<-EOH
        source #{HOME}/pyenv/bin/activate
        paster --plugin=ckanext-harvest harvester sources | grep #{harvester} || paster --plugin=ckanext-harvest harvester source #{harvester}-harvester "http://#{harvester}/" #{harvester}
    EOH

  end
end

# Put one harvester on each line inside the %w()
if RUN_HARVESTER then
  %w().each do | harvester |
    %w(gather fetch).each do | type |
      service "#{harvester}-#{type}" do
        provider Chef::Provider::Service::Upstart
        action :start
      end
    end
  end

  bash "run the harvesters" do
    user USER
    cwd CKAN_DIR
    code <<-EOH
        source #{HOME}/pyenv/bin/activate
        paster --plugin=ckanext-harvest harvester job-all
        paster --plugin=ckanext-harvest harvester run -c development.ini
      EOH
  end
end
