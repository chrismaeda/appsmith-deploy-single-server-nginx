HOWTO Deploy Appsmith on a Single Linux Server

This document describes how to a single-server "retro" install of AppSmith, with no dependencies on docker or docker-compose.

AppSmith consists of an in-browser app, a Java-based application tier, and a MongoDB.  Here, the in-browser app is server by an Nginx, which also provides a reverse proxy to the application tier.  The MongoDB may be run on this server or another.


# Requirements

* A Linux server.  This document was tested on Ubuntu 20.

## Install Packages

### Required Packages

* Nginx
* Redis
* Java 11

### MongoDB (optional)

If you decide to run MongoDB on the server...

1. Install Mongodb CE: https://docs.mongodb.com/manual/tutorial/install-mongodb-on-ubuntu/
2. Enable and Configure Security: https://docs.mongodb.com/manual/administration/security-checklist/


# Build AppSmith Server and Client

## Get source code

Check out the latest tag or get the release branch:

```
git clone https://github.com/appsmithorg/appsmith.git
git checkout tags/v1.6.1
```
or

```
git clone https://github.com/appsmithorg/appsmith.git
git checkout release
```

## Build Server

Based on: https://github.com/appsmithorg/appsmith/blob/release/contributions/ServerSetup.md

```
cd app/server
mvn clean install
./build.sh -DskipTests=true
```

This creates a server build in the dist folder.

```
tar cf server-dist.tar dist
```

Note: the server tarball has all the files in the dist folder.

Copy the server tarball to the deployment server.


## Build Client

Based on: https://github.com/appsmithorg/appsmith/blob/release/contributions/ClientSetup.md

```
cd app/client
yarn install
yarn build
```

This creates a client build in the build folder.

```
cd build
tar cf ../client-dist.tar .
```

Note: the client tarball has all the files at top level.

Copy the client tarball to the deployment server.


# Install AppSmith on Server

## Unpack Server Distribution

```
sudo mkdir /opt/appsmith
sudo chown ubuntu:ubuntu /opt/appsmith
cd /opt/appsmith
mkdir server
cd server
tar xf ~/server-dist.tar
```

## Create Server .env File

From the appsmith source tree, copy app/server/envs/dev.env.example to /opt/appsmith/server/.env

Edit this file as needed for your environment.

Important: add 'set -o allexport' to the .env file so that all the variables get exported to AppSmith.

## Unpack Client Distribution

Cd to nginx document home, usually /var/www/html, and unpack the client distribution.

```
cd /var/www/html
sudo tar xf ~/client-dist.tar
```

# Configure Nginx

## Configure Certbot TLS Certificate

Configure a TLS / HTTPS Certificate using Certbot

https://certbot.eff.org/instructions?ws=nginx&os=ubuntufocal

Certbot will modify the nginx config file at /etc/nginx/sites-available/default

Add the following to the server ssl configuration:

```
server {
        # SSL configuration
        #
        # listen 443 ssl default_server;
        # listen [::]:443 ssl default_server;
        #
        # Note: You should disable gzip for SSL traffic.
        # See: https://bugs.debian.org/773332
        #
        # Read up on ssl_ciphers to ensure a secure configuration.
        # See: https://bugs.debian.org/765782
        #
        # Self signed certs generated by the ssl-cert package
        # Don't use them in a production server!
        #
        # include snippets/snakeoil.conf;

        root /var/www/html;

        # Add index.php to the list if you are using PHP
        index index.html index.htm index.nginx-debian.html;
        server_name server.example.com; # managed by Certbot

        # ADD THESE LINES...

	location / {
                # First attempt to serve request as file, then
                # as directory, then fall back to displaying a 404.
                try_files $uri $uri/ /index.html =404;
        }

        location /api {
                proxy_pass http://localhost:8080;
        }
        
        location /oauth2 {
                proxy_pass http://localhost:8080;
        }

        location /login {
                proxy_pass http://localhost:8080;
        }
```

## Reload Nginx

```
sudo systemctl reload nginx
```


# Test Configuration

## Start Server

```
cd /opt/appsmith/server
set -o allexport
source .env
(cd dist && exec java -jar server-*.jar)
```

## Run AppSmith

Point a browser to your server: https://server.example.com/

You should be able to log in and use appsmith.


# Run Appsmith Server as a Service

## Download Tanuki Wrapper

```
wget https://download.tanukisoftware.com/wrapper/3.5.46/wrapper-linux-x86-64-3.5.46.tar.gz
gunzip -c wrapper-linux-x86-64-3.5.46.tar.gz |tar cf -
```

## Copy files from Wrapper

```
cd /opt/appmith/server
mkdir bin conf lib logs
cd wrapper-linux-x86-64-3.5.46
cp bin/wrapper /opt/appsmith/server/bin
cp lib/libwrapper.so lib/wrapper.jar /opt/appsmith/server/lib
cp src/conf/wrapper.conf.in /opt/appsmith/server/conf/wrapper.conf
cp src/bin/App.sh.in /opt/appsmith/server/bin/appsmith-server
cp src/bin/App.shconf.in /opt/appsmith/server/bin/appsmith-server.shconf
chmod +x /opt/appsmith/server/bin/appsmith-server*
```

## Configure Wrapper.conf

Edit /opt/appsmith/server/conf/wrapper.conf

You must make the following changes:

```
wrapper.java.mainclass=org.tanukisoftware.wrapper.WrapperJarApp
wrapper.java.classpath.1=../lib/wrapper.jar
wrapper.java.classpath.2=server-1.0-SNAPSHOT.jar
wrapper.app.parameter.1=server-1.0-SNAPSHOT.jar
wrapper.working.dir=../dist
```

You may also want to edit the following settings:

```
wrapper.java.command.loglevel=INFO
wrapper.logfile=../logs/appsmith-server.log
wrapper.logfile.maxsize=100m
```

See the wrapper.conf included here.

## Configure appsmith-server.shconf

The shconf file (from Wrapper's App.shconf.in) is used to configure the appsmith-server script.  Add this setting:

```
FILES_TO_SOURCE=/opt/appsmith/server/.env
```

## Install Systemd Service File

Copy the appsmith-server.service file to /etc/systemd/system

Enable and start service:

```
sudo systemctl enable appsmith-server
sudo systemctl start appsmith-server
```


## Run AppSmith

Point a browser to your server: https://server.example.com/

You should be able to log in and use appsmith.














