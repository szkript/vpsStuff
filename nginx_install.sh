#!/bin/bash
projectName=silkvideo

apt-get -y update
apt-get -y install nginx
# shellcheck disable=SC2155
export HOSTNAME=$(curl -s http://169.254.169.254/metadata/v1/hostname)
# shellcheck disable=SC2155
export PUBLIC_IPV4=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)
  echo Droplet: $HOSTNAME, IP Address: $PUBLIC_IPV4 > /usr/share/nginx/html/index.html
ufw allow 'Nginx HTTP'
systemctl reload nginx

mkdir -p /var/www/$projectName/html
chown -R $USER:$USER /var/www/$projectName/html
chmod -R 755 /var/www/$projectName

cat > /var/www/$projectName/html/index.html <<EOL
<html>
  <head>
      <title>Welcome to ngninx sample</title>
    </head>
    <body>
      <h1>Succ! nginx server block workin </h1>
    </body>
  </html>
EOL

cat > /etc/nginx/sites-available/$projectName<<EOL
server {
  listen 80;
  listen [::]:80;

  root /var/www/$projectName/html;
  index index.html index.htm index.nginx-debian.html;

  server_name $projectName $PUBLIC_IPV4;

  location / {
     try_files $uri $uri/ =404;
  }
}
EOL
ln -s etc/nginx/sites-available/$projectName /etc/nginx/sites-enabled/
chmod a+x /etc/nginx/sites-enabled/$projectName