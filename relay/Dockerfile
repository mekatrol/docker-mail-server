FROM ubuntu:latest

# Set environment variables to avoid interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Expected arguments
ARG SSH_USER_NAME
ARG SSH_USER_PASSWORD
ARG HOSTNAME
ARG MAIL_DOMAIN
ARG TIMEZONE

RUN if [ -z "$SSH_USER_NAME" ]; then \
    echo "Error: SSH_USER_NAME must be defined!" && exit 1; \
    fi

RUN if [ -z "$SSH_USER_PASSWORD" ]; then \
    echo "Error: SSH_USER_PASSWORD must be defined!" && exit 1; \
    fi

RUN if [ -z "$HOSTNAME" ]; then \
    echo "Error: HOSTNAME must be defined!" && exit 1; \
    fi

RUN if [ -z "$MAIL_DOMAIN" ]; then \
    echo "Error: MAIL_DOMAIN must be defined!" && exit 1; \
    fi

RUN if [ -z "$TIMEZONE" ]; then \
    echo "Error: TIMEZONE must be defined!" && exit 1; \
    fi

    # Install packages
RUN apt update && DEBIAN_FRONTEND=noninteractive apt install -y \
    sudo \
    syslog-ng \
    telnet \
    nano \
    tzdata \
    cron \
    openssh-server \
    certbot \
    python3-certbot-nginx \
    nginx \
    postfix

RUN rm -rf /var/lib/apt/lists/*

# The ports to expose:
#    80 - for lets encrypt to prove domain ownership in .well-known/acme-challenge
#   443 - NGINX https
#    22 - SSH
#    25 - SMTP
#   587 - SMTP AUTH
#   993 - POP3
EXPOSE 80 22 25

# Set up the cron job to renew certificates once per week
# Use to generate in first instance:
#   certbot certonly --webroot --webroot-path=/var/www/html --email admin@test.com --agree-tos --cert-name mail.test.com-rsa -d mail.test.com --key-type rsa
RUN echo "5 0 */7 * * root certbot renew --quiet && nginx -s reload" > /etc/cron.d/certbot-renewal

# Create a directory to store cron logs
RUN mkdir -p /var/log/cron

# Set cron job permissions, Owner = read/write | Group = read | Others = read
RUN chmod 0644 /etc/cron.d/certbot-renewal

# Create the SSH user and set a password
RUN useradd -m -s /bin/bash $SSH_USER_NAME && echo "$SSH_USER_NAME:$SSH_USER_PASSWORD" | chpasswd

# Add the SSH user to the sudo group
RUN usermod -aG sudo $SSH_USER_NAME

# Create SSH run file directory
RUN mkdir /var/run/sshd 

# Exclude core messages in docker cotnainer
RUN sudo sed -i 's/system()/system(exclude-kmsg(yes))/g' /etc/syslog-ng/syslog-ng.conf

RUN sudo cp /etc/postfix/master.cf /etc/postfix/master.cf.bak

# Careful of the single and double quoted strings in postconf settings (that is deliberate)
RUN sudo postconf -e "myhostname = $HOSTNAME"
RUN sudo postconf -e "mydomain = $MAIL_DOMAIN"
RUN sudo postconf -e 'myorigin = $mydomain' 
RUN sudo postconf -e 'inet_interfaces = all' 
RUN sudo postconf -e 'inet_protocols = ipv4' 
RUN sudo postconf -e 'mailbox_size_limit = 0' 
RUN sudo postconf -e 'message_size_limit = 10240000' 
RUN sudo postconf -e "smtpd_tls_cert_file = /etc/letsencrypt/live/$HOSTNAME-rsa/fullchain.pem"
RUN sudo postconf -e "smtpd_tls_key_file = /etc/letsencrypt/live/$HOSTNAME-rsa/privkey.pem"
RUN sudo postconf -e 'mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128'
RUN sudo postconf -e "relay_domains = $MAIL_DOMAIN"
RUN sudo postconf -e "relay_host = 172.16.3.200"
RUN sudo postconf -e 'mydestination = $myhostname, localhost.$mydomain, $mydomain'

# Disable local mail delivery on mailserver, we are relaying to another server
RUN sudo postconf -e 'local_recipient_maps = '

# Set cleanup options
RUN echo "/^Received:.*with ESMTPSA/ IGNORE" > /etc/postfix/header_checks 

# Set owner for nginx to www-data
RUN chown -R www-data:www-data /var/lib/nginx

# Add site config for lets encrypt to verify domain ownership
RUN echo "server {"                                                                        > /etc/nginx/sites-available/$HOSTNAME  
RUN echo "    listen 80;"                                                                 >> /etc/nginx/sites-available/$HOSTNAME
RUN echo "    listen [::]:80;"                                                            >> /etc/nginx/sites-available/$HOSTNAME
RUN echo "    server_name $HOSTNAME;"                                                     >> /etc/nginx/sites-available/$HOSTNAME
RUN echo "    root /var/www/html;"                                                        >> /etc/nginx/sites-available/$HOSTNAME
RUN echo ""                                                                               >> /etc/nginx/sites-available/$HOSTNAME
RUN echo "    location / {"                                                               >> /etc/nginx/sites-available/$HOSTNAME
RUN echo "        index index.html;"                                                      >> /etc/nginx/sites-available/$HOSTNAME
RUN echo "    }"                                                                          >> /etc/nginx/sites-available/$HOSTNAME
RUN echo ""                                                                               >> /etc/nginx/sites-available/$HOSTNAME
RUN echo "    location ~ /.well-known/acme-challenge {"                                   >> /etc/nginx/sites-available/$HOSTNAME
RUN echo "        allow all;"                                                             >> /etc/nginx/sites-available/$HOSTNAME
RUN echo "    }"                                                                          >> /etc/nginx/sites-available/$HOSTNAME
RUN echo "}"                                                                              >> /etc/nginx/sites-available/$HOSTNAME

# Create index.html just for testing site up and running
RUN echo "<!DOCTYPE html>"                                                                 > /var/www/html/index.html
RUN echo "<html lang=""en"">"                                                             >> /var/www/html/index.html
RUN echo ""                                                                               >> /var/www/html/index.html
RUN echo "<head>"                                                                         >> /var/www/html/index.html
RUN echo "    <meta charset=""UTF-8"">"                                                   >> /var/www/html/index.html
RUN echo "    <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">" >> /var/www/html/index.html
RUN echo "    <title>$MAIL_DOMAIN</title>"                                                >> /var/www/html/index.html
RUN echo "</head>"                                                                        >> /var/www/html/index.html
RUN echo ""                                                                               >> /var/www/html/index.html
RUN echo "<body>"                                                                         >> /var/www/html/index.html
RUN echo "    <p>active</p>"                                                              >> /var/www/html/index.html
RUN echo "    <span>$(date '+%Y-%m-%d %H:%M:%S')</span>"                                  >> /var/www/html/index.html
RUN echo "</body>"                                                                        >> /var/www/html/index.html
RUN echo ""                                                                               >> /var/www/html/index.html
RUN echo "</html>"                                                                        >> /var/www/html/index.html

# Set timezone
RUN  ln -fs /usr/share/zoneinfo/$TIMEZONE /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata

# Make site active
RUN ln -s /etc/nginx/sites-available/$HOSTNAME /etc/nginx/sites-enabled/$HOSTNAME

# Create container startup script
RUN echo "#!/bin/bash\n\
    sudo service syslog-ng start\n\
    sudo service cron start\n\
    sudo service ssh start\n\
    sudo service postfix start\n\
    sudo nginx -g 'daemon off;'\n\
    tail -f /var/log/mail.log" > /start.sh && chmod +x /start.sh

# Run container start up script
CMD ["/bin/bash", "/start.sh"]
