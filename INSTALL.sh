#!/bin/bash
echo "Starting Web Protection installation"
: '
First we need to update the repositories
and then install the packages and libraries
'
apt update && apt install -y git apache2-utils apt-transport-https build-essential libpcre3 libpcre3-dev libssl-dev libtool autoconf apache2-dev libxml2-dev libcurl4-openssl-dev automake pkgconf  figlet

: '
By recommendation we need to install
this ModSecurity version due to this one
is compatible with Nginx
'
cd /usr/src
git clone -b nginx_refactoring https://github.com/SpiderLabs/ModSecurity.git

: '
Compile modsecurity module
'
cd /usr/src/ModSecurity
./autogen.sh
./configure --enable-standalone-module --disable-mlogc
make

: '
We need to download Nginx version 1.12.1 due to this version
it the lastest compatible with headers to remove headers from responses
to avoid any information leakage about nginx version, here also compile nginx with
modsecurity module, ssl and headers.
'
cd /usr/src
wget https://nginx.org/download/nginx-1.12.1.tar.gz
tar -zxvf nginx-1.12.1.tar.gz && rm -f nginx-1.12.1.tar.gz
wget https://github.com/openresty/headers-more-nginx-module/archive/v0.32.tar.gz
tar -zxvf v0.32.tar.gz && rm -rf v0.32.tar.gz
cd /usr/src/nginx-1.12.1/
/usr/src/nginx-1.12.1/configure --user=www-data --group=www-data --add-module=/usr/src/headers-more-nginx-module-0.32 --add-module=/usr/src/ModSecurity/nginx/modsecurity --with-http_ssl_module
make
make install

: '
Print out the nginx files and their location in the system.
'

echo "Nginx files and their paths"
echo -e "\n"
echo "nginx path prefix: "/usr/local/nginx" "
echo "nginx binary file: "/usr/local/nginx/sbin/nginx" "
echo "nginx modules path: "/usr/local/nginx/modules" "
echo "nginx configuration prefix: "/usr/local/nginx/conf" "
echo "nginx configuration file: "/usr/local/nginx/conf/nginx.conf" "
echo "nginx pid file: "/usr/local/nginx/logs/nginx.pid" "
echo "nginx error log file: "/usr/local/nginx/logs/error.log" "
echo "nginx http access log file: "/usr/local/nginx/logs/access.log" "
echo "nginx http client request body temporary files: "client_body_temp" "
echo "nginx http proxy temporary files: "proxy_temp" "
echo "nginx http fastcgi temporary files: "fastcgi_temp" "
echo "nginx http uwsgi temporary files: "uwsgi_temp" "
echo "nginx http scgi temporary files: "scgi_temp" "
echo -e "\n"
echo "Wait 20 seconds to continue..."
sleep 20

: '
We checked nginx configuration to notice if there is some 
issue within it
'
echo "Checking Nginx configuration... "
/usr/local/nginx/sbin/nginx -t
sleep 60

: '
Copy the file nginx.service from nginx_files, this file help us
to create the service in operating system to start, stop and retart 
the service in an easier way
'
cp -p ~/Web_Protection/nginx_files/nginx.service /lib/systemd/system/nginx.service


: '
Creation of modsec files that contains all ModSecurity configuration
inclues files and rules needed to begin to protect web server through nginx
'
touch /usr/local/nginx/conf/modsec_includes.conf
cat <<EOF>> /usr/local/nginx/conf/modsec_includes.conf
include modsecurity.conf
include owasp-modsecurity-crs/crs-setup.conf
include owasp-modsecurity-crs/rules/*.conf
EOF

: '
Copy needed files from ModSecurity downloaded package 
to local nginx installation
'
cp -p /usr/src/ModSecurity/modsecurity.conf-recommended /usr/local/nginx/conf/modsecurity.conf
cp -p /usr/src/ModSecurity/unicode.mapping /usr/local/nginx/conf/

: '
Change default mode from Detectio to On, "On" means that ModSecurity begin to block
requests or attacks acording to the rule set installed
'
sed -i "s/SecRuleEngine DetectionOnly/SecRuleEngine On/" /usr/local/nginx/conf/modsecurity.conf

: '
Add the free modsecurity rules from SpiderLabs github repository
'
cd /usr/local/nginx/conf
git clone https://github.com/SpiderLabs/owasp-modsecurity-crs.git
cd owasp-modsecurity-crs
mv crs-setup.conf.example crs-setup.conf
cd rules
mv REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
mv RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf.example RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf

: '
To apply all the above configuration we need to restart 
nginx services.
'
systemctl restart nginx.service

: '
We enable and install IPTABLES to improve security in the server
Port: 9200 is related to elasticsearch (listening just in localhost)
Port: 5601 is related to Kibana interface (listening just in localhost)
'
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 9200 -j ACCEPT
iptables -A INPUT -p tcp --dport 5601 -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT
iptables -P FORWARD DROP
touch /etc/iptables
iptables-save > /etc/iptables

: '
Make a copy of the original nginx.conf file and then copy the modified one,
where we established all the tunned configuration.
Also we copy all the necessary files to our modified nginx
'
echo "Setting up Nginx Configuration"
mkdir /usr/local/nginx/ssl
mv /usr/local/nginx/conf/nginx.conf /usr/local/nginx/conf/nginx.conf.bkp
cp ~/Web_Protection/nginx_files/nginx.conf /usr/local/nginx/conf/
cp ~/Web_Protection/nginx_files/blockuseragents.rules /usr/local/nginx/
echo "....."
echo "Copying sites files to /usr/local/nginx/conf.d/"
mkdir /usr/local/nginx/conf.d
cp ~/Web_Protection/nginx_files/kibana.* /usr/local/nginx/conf.d/

: '
To increase SSL security we need to create  DH certificate and this 
append within each site configuration files
'
sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

: '
Create htpasswd file to enable Basic Authentication in Nginx and append 
user wprotector as default user for it.
'
touch /usr/local/nginx/.htpasswd
echo 'wprotector:$apr1$oSGLXVI9$/xB3u5Xey0xfugyo8P4Y60' >>  /usr/local/nginx/.htpasswd

: '
To apply all the new configuration, nginx is needed to be restarted
'
systemctl restart nginx.service


: '
To install ELK stack, first we need to install JAVA
'
touch /etc/apt/sources.list.d/java-8-debian.list
echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" | sudo tee -a /etc/apt/sources.list.d/java-8-debian.list
echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" | sudo tee -a /etc/apt/sources.list.d/java-8-debian.list

: '
For above repositories we need to add the following key to be able 
to download and install JAVA
'
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EEA14886

: '
Installing JAVA, since is necessary to install ELK stack
'
echo "Installing java..."
apt-get update && apt-get install oracle-java8-installer -y

: '
From here we install ELK stack, we first to import/download the key to install 
from repositories
'
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -

: '
Add repository to elastic source
'
echo "deb https://artifacts.elastic.co/packages/5.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-5.x.list

: '
We install all ELK stack at once 
'
echo "Installing ELK stack..."
apt-get update && apt-get install logstash elasticsearch kibana -y

: '
We need to create some directories to copy modified files for logstash, 
* Logstash is the one that first normilized the incoming information from ModSecurity
and separete it in fields that elasticsearch can read and organize 
'
echo "Logstash is configuring itself"
mkdir /opt/Web_Protection/
mkdir /opt/Web_Protection/logstash-modsecurity
cp -r /root/Web_Protection/ELK_Files/* /opt/Web_Protection/logstash-modsecurity/

: '
After copy the modified files we need to run deploy script to install (configure)
all necessary files to give logstash the ability to process the logs from modsecurity log
'
bash /opt/Web_Protection/logstash-modsecurity/deploy.sh

: '
At last we need to change permissions to give logstash user permission to read
ModSecurity log and process it.
'
setfacl -m u:logstash:r /var/log/modsec_audit.log

: '
Since we have modified all the ELK stack files to suit our needs
we need to copy those configuration files to their respective paths
'
mv /etc/kibana/kibana.yml /etc/kibana/kibana.bkp
cp ~/Web_Protection/kibana/kibana.yml /etc/kibana/
cp -R ~/Web_Protection/logstash/* /etc/logstash/
cp -R ~/Web_Protection/elasticsearch/* /etc/elasticsearch/

: '
To apply the configuration changes we need to restart all ELK stack
components
'
echo "Restarting ELK services..."
service logstash restart
service elasticsearch restart
service kibana restart


###Instaling Menu Script ###
