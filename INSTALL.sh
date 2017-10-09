#!/bin/bash

###Actualizar e instalar dependencias###
apt update && apt install -y git apache2-utils apt-transport-https build-essential libpcre3 libpcre3-dev libssl-dev libtool autoconf apache2-dev libxml2-dev libcurl4-openssl-dev automake pkgconf

###Es recomendable utilizar esta version para nginx de modSecurity###
cd /usr/src
git clone -b nginx_refactoring https://github.com/SpiderLabs/ModSecurity.git

###Compilar ModSecurity###
cd /usr/src/ModSecurity
./autogen.sh
./configure --enable-standalone-module --disable-mlogc
make

###Compilar Nginx###
cd /usr/src
wget https://nginx.org/download/nginx-1.12.1.tar.gz
tar -zxvf nginx-1.12.1.tar.gz && rm -f nginx-1.12.1.tar.gz
wget https://github.com/openresty/headers-more-nginx-module/archive/v0.32.tar.gz
tar -zxvf v0.32.tar.gz && rm -rf v0.32.tar.gz
cd /usr/src/nginx-1.12.1/
/usr/src/nginx-1.12.1/configure --user=www-data --group=www-data --add-module=/usr/src/headers-more-nginx-module-0.32 --add-module=/usr/src/ModSecurity/nginx/modsecurity --with-http_ssl_module
make
make install

###Modificar el usuario default Nginx### <-- Paso no necesario, se reemplaza archivo ngnix.conf
##sed -i "s/#user  nobody;/user www-data www-data;/" /usr/local/nginx/conf/nginx.conf 

###Los archivos de nginx su localizacion###

echo "Estos son los archivos de Nginx"
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
echo "Espera 10 segundos para continuar..."

sleep 10

###Probar la configuracion de nginx###
echo "Probando configuracion... "
/usr/local/nginx/sbin/nginx -t
sleep 60

####Configurar systemd unit file###
#/lib/systemd/system/nginx.service
cp -p /root/WebProtection_Installation/nginx_files/nginx.service /lib/systemd/system/nginx.service

###Crear archivo modsec_includes.conf###
touch /usr/local/nginx/conf/modsec_includes.conf
cat <<EOF>> /usr/local/nginx/conf/modsec_includes.conf
include modsecurity.conf
include owasp-modsecurity-crs/crs-setup.conf
include owasp-modsecurity-crs/rules/*.conf
EOF

###Importar archivos de configuracion de modsecurity###
cp -p /usr/src/ModSecurity/modsecurity.conf-recommended /usr/local/nginx/conf/modsecurity.conf
cp -p /usr/src/ModSecurity/unicode.mapping /usr/local/nginx/conf/

### Habilitar motor de boqueo ###
sed -i "s/SecRuleEngine DetectionOnly/SecRuleEngine On/" /usr/local/nginx/conf/modsecurity.conf

###Agregar Core Set Rules###
cd /usr/local/nginx/conf
git clone https://github.com/SpiderLabs/owasp-modsecurity-crs.git
cd owasp-modsecurity-crs
mv crs-setup.conf.example crs-setup.conf
cd rules
mv REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
mv RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf.example RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf

###Reiniciar nginx###
systemctl restart nginx.service


###Remplazar archivos nginx.conf y agregar kibana.example para usarse en script MENU.sh###
echo "Replacing /usr/local/nginx/conf/nginx.conf with $HOME/nginx_files/nginx.conf"
mv /usr/local/nginx/conf/nginx.conf /usr/local/nginx/conf/nginx.conf.bkp
cp ~/WebProtection_Installation/nginx_files/nginx.conf /usr/local/nginx/conf/
echo "....."
echo "Copying kibana.example to /usr/local/nginx/conf.d/"
mkdir /usr/local/nginx/conf.d
cp ~/WebProtection_Installation/nginx_files/kibana.* /usr/local/nginx/conf.d/

### Crear certificado DH ###
sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

###Install ELK###
###Download GPG KEy and add it###
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -

###Agregar repositorios###
echo "deb https://artifacts.elastic.co/packages/5.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-5.x.list

###Instalar componentes de ELK###
echo "Installing ELK stack..."
apt-get update && apt-get install logstash elasticsearch kibana -y

###Configure logstash###
###clonar repositorio###
###git clone https://github.com/bitsofinfo/logstash-modsecurity.git

#Modificar o copiar todos los archivos que se encuentran en ELK_files
echo "Copiar archivos de /ELK_Files to /logstash-modsecurity"
mkdir /root/WebProtection_Installation/logstash-modsecurity
cp -r /root/WebProtection_Installation/ELK_Files/* /root/WebProtection_Installation/logstash-modsecurity/

###Ejecutar deploy.sh###
bash /root/WebProtection_Installation/logstash-modsecurity/deploy.sh

###Cambiar permiso de log modsecurity###
setfacl -m u:logstash:r /var/log/modsec_audit.log

###Copiar archivos ya configurados###
mv /etc/kibana/kibana.yml /etc/kibana/kibana.bkp
cp ~/WebProtection_Installation/kibana/kibana.yml /etc/kibana/
cp -R ~/WebProtection_Installation/logstash/* /etc/logstash/
cp -R ~/WebProtection_Installation/elasticsearch/* /etc/elasticsearch/

###Reiniciar servicios###
echo "Restarting ELK services..."
service logstash restart
service elasticsearch restart
service kibana restart
