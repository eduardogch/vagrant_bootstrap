#!/usr/bin/env bash
# Vagrant bootstrap script to setup a Ubuntu Server with Nodejs, NPM, MongoDB, Redis & Nginx
APP_FOLDER='/var/www/myapp'
APP_NAME='myapp'
NODE_APP_IP='127.0.0.1'
NODE_APP_PORT='3000'

# update / upgrade
sudo apt-get update
sudo apt-get -y upgrade

# install required packages
sudo apt-get install -y build-essential git curl nginx

# config git
git config --global user.name "Eduardo Gonzalez"
git config --global user.email eduardo.gch@gmail.com
git config --global url."https://".insteadOf git://
git config --global http.sslVerify false
git config --global color.ui true

# install Nodejs
curl -sL https://deb.nodesource.com/setup_5.x | sudo -E bash -
sudo apt-get install -y nodejs mongodb
sudo ln -s /usr/bin/nodejs /usr/bin/node
npm config set strict-ssl false
npm config set registry http://registry.npmjs.org/
npm install -g npm node-gyp node-sass pm2 bower gulp strongloop mocha karma-cli strider

# install Redis
sudo apt-get -y install redis-server
sudo update-rc.d redis-server defaults
sudo /etc/init.d/redis-server start

# Startup Node App
cd ${APP_FOLDER}
sudo rm -rf /node_modules /public /source/bower_components npm-debug.log
npm install --no-bin-links
bower update --config.interactive=false && gulp build
pm2 start ${APP_FOLDER}/server/server.js --name ${APP_NAME}
pm2 startup ubuntu
sudo su -c "env PATH=$PATH:/usr/bin pm2 startup ubuntu -u vagrant --hp /home/vagrant"

# config nginx
VHOST=$(cat <<EOF
server {
    listen 80;

    server_name ${APP_NAME}.com;
    root ${APP_FOLDER}/public;

    location / {
        proxy_pass http://${NODE_APP_IP}:${NODE_APP_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    location /api {
        proxy_pass http://${NODE_APP_IP}:${NODE_APP_PORT};
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-NginX-Proxy true;
        proxy_ssl_session_reuse off;
        proxy_set_header Host \$http_host;
        proxy_redirect off;
    }

}
EOF)
echo "${VHOST}" > /etc/nginx/sites-available/default
sudo nginx -t
sudo service nginx restart
