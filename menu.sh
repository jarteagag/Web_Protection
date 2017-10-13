#!/bin/bash
trap '' 2
clear
while true
do
  
  echo "==============================================="
  figlet "EWS Web"  
  echo "==============================================="
  echo "Enter 1) to start Nginx service: "
  echo "Enter 2) to stop Nginx service: "
  echo "Enter 3) to restart Nginx service: "
  echo "Enter 4) to start ELK services: "
  echo "Enter 5) to stop ELK services: "
  echo "Enter 6) to restart ELK services: "
  echo "Enter 7) to add URL: "
  echo "Enter 8) to add URL with SSL: "
  echo "Enter 9) to remove URL: "
  echo "Enter q) to Exit: "
  echo -e "\n"
  echo -e "Enter your selection: \c"
  read answer
  case "$answer" in
    1)systemctl start nginx.service ;;
    
    2)systemctl stop nginx.service ;;
    
    3)systemctl restart nginx.service ;;
    
    4)service elasticsearch restart
    service logstash restart
    service kibana restart ;;
    
    5)service elasticsearch stop
    service logstash stop
    service kibana stop ;;
      
    6)service elasticsearch restart
    service logstash restart
    service kibana restart ;;   
    
    7)echo "Enter the URL that you want to proctect: "
    read url
    cat /home/kibana_http.example > $url.conf
    sed -i s/kibana.skipficloud.io/$url/g /home/$url.conf
    echo "Enter the backend URL or IP and port (if has non-standard port) IP:PORT: "
    read backend
    sed -i s/127.0.0.1:5601/$backend/g /home/$url.conf
    echo "Restart SKIPFI Web Protection engine..." ;;
    
    8) echo "Enter the URL that you want to protect (SSL): "
    read url_ssl
    cat /home/kibana_https.example > /home/$url_ssl.ssl.conf
    sed -i s/kibana.skipficloud.io/$url_ssl/g /home/$url_ssl.ssl.conf
    echo "Enter the backend URL or IP and port (if has non-standard port) IP:PORT: "
    read backend
    sed -i s/127.0.0.1:5601/$backend/g /home/$url_ssl.ssl.conf
    echo "If the backend is listening in HTTPs protocol press (YES): "
    read protocol
    	if [ "$protocol" = "YES" ];	then 
			sed -i 's/proxy_pass http/proxy_pass https/g' /home/$url_ssl.ssl.conf
			echo "The protocol used in backend is HTTPs"
		else
			echo "The protocol used in backend is HTTP"
		fi		
    echo "Enter the key name stored in PATH: "
    read key
    sed -i 's/\/home\/alejandro_lopezrm\/nginx.key/\/usr\/local\/nginx\/ssl\/'$key/g /home/$url_ssl.ssl.conf
    echo "Enter the certificate name stored in PATH: "
    read certificate
    sed -i 's/\/home\/alejandro_lopezrm\/nginx.pem/\/usr\/local\/nginx\/ssl\/'$certificate/g /home/$url_ssl.ssl.conf
    echo "Restart SKIPFI Web Protection engine..." ;;
    
    9) echo "Enter the URL that you want to delete: "
    read delete_url
    echo "The URL is with SSL? (YES/NO)"
    read answer
    	if [ "$answer" = "YES"]; then
    		rm -rf /usr/local/nginx/conf.d/$delete_url.ssl.conf
    	else
    		rm -rf /usr/local/nginx/conf.d/$delete_url.conf
    	fi;;
    
    q)  exit ;;
  
  esac
  echo -e "Enter return to continue \c"
  read input
  clear
done