FROM ubuntu:latest

# Set environment variables to avoid interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Expected arguments
ARG DB_NAME
ARG POSTGRES_PASSWORD
ARG DB_ADMIN_NAME
ARG DB_ADMIN_PASSWORD
ARG DB_READER_NAME
ARG DB_READER_PASSWORD
ARG SSH_USER_NAME
ARG SSH_USER_PASSWORD
ARG HOSTNAME
ARG MAIL_DOMAIN
ARG TIMEZONE

# Validate arguments have been set
RUN if [ -z "$DB_NAME" ]; then \
    echo "Error: DB_NAME must be defined!" && exit 1; \
    fi

RUN if [ -z "$POSTGRES_PASSWORD" ]; then \
    echo "Error: POSTGRES_PASSWORD must be defined!" && exit 1; \
    fi

RUN if [ -z "$DB_ADMIN_NAME" ]; then \
    echo "Error: DB_ADMIN_NAME must be defined!" && exit 1; \
    fi

    RUN if [ -z "$DB_ADMIN_PASSWORD" ]; then \
    echo "Error: DB_ADMIN_PASSWORD must be defined!" && exit 1; \
    fi

RUN if [ -z "$DB_READER_NAME" ]; then \
    echo "Error: DB_READER_NAME must be defined!" && exit 1; \
    fi

RUN if [ -z "$DB_READER_PASSWORD" ]; then \
    echo "Error: DB_READER_PASSWORD must be defined!" && exit 1; \
    fi

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
    nginx \
    certbot \
    python3-certbot-nginx \
    postfix postfix-pgsql \
    dovecot-core dovecot-imapd dovecot-pop3d dovecot-pgsql \
    postgresql postgresql-contrib 

RUN rm -rf /var/lib/apt/lists/*

# The ports ot expose:
#    80 - for lets encrypt to prove domain ownership in .well-known/acme-challenge
#   443 - NGINX https
#    22 - SSH
#    25 - SMTP
#   587 - SMTP AUTH
#   993 - POP3
EXPOSE 80 443 22 25 587 993

# Set up the cron job to renew certificates once per week
# Use to generate in first instance:
#   certbot certonly --webroot --webroot-path=/var/www/html --email admin@test.com --agree-tos --cert-name mail.test.com-rsa -d mail.test.com --key-type rsa
RUN echo "0 0 */7 * * root certbot renew --quiet && nginx -s reload" > /etc/cron.d/certbot-renewal

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

# Create mailreader group
RUN sudo groupadd $DB_READER_NAME

# Create mailreader user
RUN sudo useradd -g $DB_READER_NAME -d /home/mail -s /sbin/nologin $DB_READER_NAME

# Create users mail directory root and change owner to mail reader account
RUN sudo mkdir /home/mail
RUN sudo chown $DB_READER_NAME:$DB_READER_NAME /home/mail

# Set up PostgreSQL
RUN service postgresql start && \
    sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$POSTGRES_PASSWORD';"  && \
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"  && \
    sudo -u postgres psql -d $DB_NAME -c "CREATE USER $DB_ADMIN_NAME WITH PASSWORD '$DB_ADMIN_PASSWORD';"  && \
    sudo -u postgres psql -d $DB_NAME -c "CREATE USER $DB_READER_NAME WITH PASSWORD '$DB_READER_PASSWORD';"  && \
    sudo -u postgres psql -d $DB_NAME -c "CREATE TABLE users (email VARCHAR PRIMARY KEY, password VARCHAR, realname VARCHAR, maildir VARCHAR NOT NULL, created TIMESTAMP WITH TIME ZONE DEFAULT now());"  && \    
    sudo -u postgres psql -d $DB_NAME -c "CREATE TABLE transports (domain VARCHAR PRIMARY KEY, gid INTEGER UNIQUE NOT NULL, transport VARCHAR NOT NULL);"  && \    
    sudo -u postgres psql -d $DB_NAME -c "CREATE TABLE aliases (alias VARCHAR PRIMARY KEY, email VARCHAR NOT NULL);"  && \    
    sudo -u postgres psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_ADMIN_NAME;"  && \
    sudo -u postgres psql -d $DB_NAME -c "GRANT SELECT ON users TO $DB_ADMIN_NAME;"  && \
    sudo -u postgres psql -d $DB_NAME -c "GRANT UPDATE ON users TO $DB_ADMIN_NAME;"  && \
    sudo -u postgres psql -d $DB_NAME -c "GRANT SELECT ON aliases TO $DB_ADMIN_NAME;"  && \
    sudo -u postgres psql -d $DB_NAME -c "GRANT UPDATE ON aliases TO $DB_ADMIN_NAME;"  && \
    sudo -u postgres psql -d $DB_NAME -c "GRANT SELECT ON transports TO $DB_READER_NAME;" && \
    sudo -u postgres psql -d $DB_NAME -c "GRANT UPDATE ON transports TO $DB_READER_NAME;" && \
    sudo -u postgres psql -d $DB_NAME -c "GRANT SELECT ON users TO $DB_READER_NAME;"  && \
    sudo -u postgres psql -d $DB_NAME -c "GRANT SELECT ON aliases TO $DB_READER_NAME;"  && \
    sudo -u postgres psql -d $DB_NAME -c "GRANT SELECT ON transports TO $DB_READER_NAME;"

# Copy the users definition file
COPY users.csv /users.csv

# Copy the user add shell script
COPY add_users.sh /add_users.sh

# Set the DB name in the add users script
RUN sudo sed -i "s/DB_NAME=\"maildb\"/DB_NAME=$DB_NAME/" /add_users.sh

# Set the group ID in the add users script
RUN sudo sed -i "s/GROUP_ID=\"1002\"/GROUP_ID=\"$(id -g $DB_READER_NAME)\"/" /add_users.sh

# Make executable
RUN chmod +x /add_users.sh

# Configure SQL for reading users
RUN echo "user=$DB_READER_NAME" > /etc/postfix/users.cf
RUN echo "password=$DB_READER_PASSWORD" >> /etc/postfix/users.cf
RUN echo "dbname=$DB_NAME" >> /etc/postfix/users.cf
RUN echo "table=users" >> /etc/postfix/users.cf
RUN echo "select_field=maildir" >> /etc/postfix/users.cf
RUN echo "where_field=email" >> /etc/postfix/users.cf
RUN echo "hosts=localhost" >> /etc/postfix/users.cf

# Configure SQL for reading aliases
RUN echo "user=$DB_READER_NAME" > /etc/postfix/aliases.cf
RUN echo "password=$DB_READER_PASSWORD" >> /etc/postfix/aliases.cf
RUN echo "dbname=$DB_NAME" >> /etc/postfix/aliases.cf
RUN echo "table=aliases" >> /etc/postfix/aliases.cf
RUN echo "select_field=email" >> /etc/postfix/aliases.cf
RUN echo "where_field=alias" >> /etc/postfix/aliases.cf
RUN echo "hosts=localhost" >> /etc/postfix/aliases.cf

# Configure SQL for reading transports
RUN echo "user=$DB_READER_NAME" > /etc/postfix/transports.cf
RUN echo "password=$DB_READER_PASSWORD" >> /etc/postfix/transports.cf
RUN echo "dbname=$DB_NAME" >> /etc/postfix/transports.cf
RUN echo "table=transports" >> /etc/postfix/transports.cf
RUN echo "select_field=transport" >> /etc/postfix/transports.cf
RUN echo "where_field=domain" >> /etc/postfix/transports.cf
RUN echo "hosts=localhost" >> /etc/postfix/transports.cf

RUN sudo cp /etc/postfix/master.cf /etc/postfix/master.cf.bak

RUN sed -i '/^#submission inet n[[:space:]]\+-[[:space:]]\+y[[:space:]]\+-[[:space:]]\+-[[:space:]]\+smtpd/,/^#/c\
submission inet n       -       y       -       -       smtpd\n\
  -o syslog_name=postfix/submission\n\
  -o smtpd_tls_wrappermode=no\n\
  -o smtpd_tls_security_level=encrypt\n\
  -o smtpd_sasl_auth_enable=yes\n\
  -o smtpd_sasl_type=dovecot\n\
  -o smtpd_sasl_path=private/auth' /etc/postfix/master.cf

RUN sed -i '0,/^#  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject/s/^#  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject/  -o smtpd_recipient_restrictions=permit_mynetworks,permit_sasl_authenticated,defer/' /etc/postfix/master.cf

RUN sed -i '/cleanup   unix  n       -       y       -       0       cleanup/c\
cleanup   unix  n       -       y       -       0       cleanup\n\
  -o header_checks=regexp:/etc/postfix/header_checks' /etc/postfix/master.cf

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
RUN sudo postconf -e 'mydestination = $myhostname, localhost.$mydomain, $mydomain'

# Disable local mail delivery on mailserver, we are using virtual mailboxes
RUN sudo postconf -e 'local_recipient_maps = '

# Set the owner of all mailboxes to 
RUN sudo postconf -e "virtual_uid_maps = static:$(id -u $DB_READER_NAME)"
RUN sudo postconf -e "virtual_gid_maps = static:$(id -g $DB_READER_NAME)"

# Set virtual mailbox bas address
RUN sudo postconf -e 'virtual_mailbox_base = /home/mail/'

# Configre how to map to virtual mailboxes
RUN sudo postconf -e 'virtual_mailbox_maps = pgsql:/etc/postfix/users.cf'

# Configure how to map to aliases
RUN sudo postconf -e 'virtual_alias_maps = pgsql:/etc/postfix/aliases.cf'

# Configure how to map to transports
RUN sudo postconf -e 'transport_maps = pgsql:/etc/postfix/transports.cf'

# Set cleanup options
RUN echo "/^Received:.*with ESMTPSA/ IGNORE" > /etc/postfix/header_checks 

# Configure Dovecot master.cf
RUN sudo cp /etc/dovecot/conf.d/10-master.conf /etc/dovecot/conf.d/10-master.conf.bak
RUN sed -i '/unix_listener auth-userdb {/,/}/c\
unix_listener auth-userdb {\n\
    path = /var/spool/postfix/private/auth\n\
    mode = 0600\n\
    user = postfix\n\
    group = postfix\n\
  }' /etc/dovecot/conf.d/10-master.conf

# Configure Dovecot SSL
RUN sudo cp /etc/dovecot/conf.d/10-ssl.conf /etc/dovecot/conf.d/10-ssl.conf.bak
RUN sudo sed -i 's/^ssl = yes/ssl = required/' /etc/dovecot/conf.d/10-ssl.conf
RUN sudo sed -i "s/^ssl_cert = <\/etc\/dovecot\/private\/dovecot.pem/ssl_cert = <\/etc\/letsencrypt\/live\/$HOSTNAME-rsa\/fullchain.pem/" /etc/dovecot/conf.d/10-ssl.conf
RUN sudo sed -i "s/^ssl_key = <\/etc\/dovecot\/private\/dovecot.key/ssl_key = <\/etc\/letsencrypt\/live\/$HOSTNAME-rsa\/privkey.pem/" /etc/dovecot/conf.d/10-ssl.conf
RUN sudo sed -i 's/^#ssl_min_protocol = TLSv1.2/ssl_min_protocol = TLSv1.2/' /etc/dovecot/conf.d/10-ssl.conf
RUN sudo sed -i 's/^#ssl_prefer_server_ciphers = no/ssl_prefer_server_ciphers = yes/' /etc/dovecot/conf.d/10-ssl.conf

# Configure Dovecot auth for SQL
RUN sudo sed -i 's/^!include auth-system.conf.ext/#!include auth-system.conf.ext/' /etc/dovecot/conf.d/10-auth.conf
RUN sudo sed -i 's/^#!include auth-sql.conf.ext/!include auth-sql.conf.ext/' /etc/dovecot/conf.d/10-auth.conf

# We want to prefetch user information when querying password
# See: https://doc.dovecot.org/2.3/configuration_manual/authentication/prefetch_userdb/#authentication-prefetch-userdb
RUN sudo sed -i '/^userdb[[:space:]]*{/,/^}/ {/^\s*driver = sql/s/driver = sql/driver = prefetch/}' /etc/dovecot/conf.d/auth-sql.conf.ext
RUN sudo sed -i '/^userdb[[:space:]]*{/,/^}/ {/^\s*args = \/etc\/dovecot\/dovecot-sql.conf.ext/s/^/# /}' /etc/dovecot/conf.d/auth-sql.conf.ext

# Set IDs of mail read group and account
RUN sudo sed -i "s/^#mail_uid =/mail_uid = $DB_READER_NAME/" /etc/dovecot/conf.d/10-mail.conf
RUN sudo sed -i "s/^#mail_gid =/mail_gid = $DB_READER_NAME/" /etc/dovecot/conf.d/10-mail.conf

# Debugging Dovecot (un comment these to see debug info in dovecot logging)
# RUN sudo sed -i 's/^#auth_verbose = no/auth_verbose = yes/' /etc/dovecot/conf.d/10-logging.conf
# RUN sudo sed -i 's/^#auth_verbose_passwords = no/auth_verbose_passwords = yes/' /etc/dovecot/conf.d/10-logging.conf
# RUN sudo sed -i 's/^#auth_debug = no/auth_debug = yes/' /etc/dovecot/conf.d/10-logging.conf
# RUN sudo sed -i 's/^#auth_debug_passwords = no/auth_debug_passwords = yes/' /etc/dovecot/conf.d/10-logging.conf
# RUN sudo sed -i 's/^#mail_debug = no/mail_debug = yes/' /etc/dovecot/conf.d/10-logging.conf
# RUN sudo sed -i 's/^#verbose_ssl = no/verbose_ssl = yes/' /etc/dovecot/conf.d/10-logging.conf

# Configure Dovecot to use PostgreSQL for virtual users 
RUN echo "driver = pgsql" > /etc/dovecot/dovecot-sql.conf.ext \
    && echo "connect = host=localhost dbname=$DB_NAME user=$DB_READER_NAME password=$DB_READER_PASSWORD" >> /etc/dovecot/dovecot-sql.conf.ext \
    && echo "default_pass_scheme = BLF-CRYPT" >> /etc/dovecot/dovecot-sql.conf.ext \
    && echo "password_query = SELECT email as user, password, 'maildir:/home/mail/'||maildir as userdb_mail FROM users WHERE email = '%u'" >> /etc/dovecot/dovecot-sql.conf.ext

# Create directories for Postfix and Dovecot
RUN mkdir -p /var/mail/vhosts && chown -R dovecot:dovecot /var/mail/vhosts

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
    sudo service postgresql start\n\
    sudo service postfix start\n\
    sudo service dovecot start\n\
    sudo nginx -g 'daemon off;'\n\
    tail -f /var/log/mail.log" > /start.sh && chmod +x /start.sh

# Run container start up script
CMD ["/bin/bash", "/start.sh"]
