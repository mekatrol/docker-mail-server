# Configuring cloud MTA to use on-premises MTA

# On a new digital ocean Ubuntu droplet

## Update packages

```bash
apt update && apt upgrade -y
```

## Set host name to fqdns

Update the following files to FQDN hostname and then reboot

* `nano /etc/hostname`
* `nano /etc/hosts`

## Set up SSH

### Add ssh user

```bash
# Change `user` to actual new user name
export SSH_USER=user

# Create user home and copy SSH key
mkdir -p /home/$SSH_USER/.ssh
cp /root/.ssh/authorized_keys /home/$SSH_USER/.ssh/

# Add user
useradd -d /home/$SSH_USER $SSH_USER -s /bin/bash

# user to SUDOers group
usermod -aG sudo $SSH_USER

# Set ownership to new user
chown -R $SSH_USER:$SSH_USER /home/$SSH_USER/

# Set permissions
chmod 700 /home/$SSH_USER/.ssh
chmod 600 /home/$SSH_USER/.ssh/authorized_keys

# Now set the users password
passwd $SSH_USER
```

### Sign in as user via SSH

> Make sure you can sign in over SSH as the user and do a `sudo su` successfully.

### Disable root login via ssh

Sign in as the new user

```bash
sudo nano /etc/ssh/sshd_config
```

Set PermitRootLogin to no
```ini
PermitRootLogin no
```

Save, exit and reboot machine

```bash
sudo reboot
```

## Set up certificates using certmon, we'll use nginx to allow Lets Encrypt to validate we own the DNS record.

Install needed packages (nginx and certbot)
```bash
sudo apt install nginx certbot python3-certbot-nginx -y
```

Configure NGINX for verifying hostname ownership

```bash
# Set owner for nginx to www-data
sudo chown -R www-data:www-data /var/lib/nginx

# Configure acme challenge
cat <<EOF | sudo tee /etc/nginx/sites-available/$HOSTNAME > /dev/null
server {
    listen 80;
    listen [::]:80;
    server_name $HOSTNAME;
    root /var/www/html;

    location / {
        index index.html;
    }

    location ~ /.well-known/acme-challenge {
        allow all;
    }
}
EOF

# Create index.html
cat <<EOF | sudo tee /var/www/html/index.html > /dev/null
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$HOSTNAME</title>
</head>
<body>
    <p>active</p>
    <span>$(date '+%Y-%m-%d %H:%M:%S')</span>
</body>
</html>
EOF

# Enable site
sudo ln -s /etc/nginx/sites-available/$HOSTNAME /etc/nginx/sites-enabled/$HOSTNAME

# Restart NGINX
sudo service nginx restart
```

Run certbot for the first time
```bash
sudo certbot certonly --webroot --webroot-path=/var/www/html --email admin@$HOSTNAME --agree-tos --cert-name $HOSTNAME-rsa -d $HOSTNAME --key-type rsa
```

## Install postfix

```bash
sudo apt install postfix -y
```

> When prompted select `Internet Site` and set your mail server host name (it will default to machine host name).

As a quick check start the postfix service, view logs, then stop the service. You should successfully see log entries with no errors.
```bash
sudo service postfix start
sudo tail -n 100 /var/log/mail.log
sudo service postfix stop
```