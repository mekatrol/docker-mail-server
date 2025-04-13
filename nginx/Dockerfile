FROM ubuntu:latest

# Set environment variables to avoid interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Expected arguments
ARG SSH_USER_NAME
ARG SSH_USER_PASSWORD
ARG HOSTNAME
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

RUN if [ -z "$TIMEZONE" ]; then \
    echo "Error: TIMEZONE must be defined!" && exit 1; \
    fi

# Install packages
RUN apt update && DEBIAN_FRONTEND=noninteractive apt install -y \
    sudo \
    syslog-ng \
    nano \
    tzdata \
    cron \
    openssh-server \
    certbot \
    python3-certbot-nginx \
    nginx

RUN rm -rf /var/lib/apt/lists/*

# The ports to expose:
#    80 - for lets encrypt to prove domain ownership in .well-known/acme-challenge
#   443 - NGINX https
EXPOSE 80 443

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

# Set owner for nginx to www-data
RUN chown -R www-data:www-data /var/lib/nginx

# Copy the reverse proxy definition file
COPY reverse_proxy_list.txt /reverse_proxy_list.txt

# Copy the reverse proxy configure shell script
COPY configure_reverse_proxy.sh /configure_reverse_proxy.sh

# Make shell script executable
RUN chmod +x /configure_reverse_proxy.sh

# Run the configuration script
RUN /configure_reverse_proxy.sh

# Set timezone
RUN  ln -fs /usr/share/zoneinfo/$TIMEZONE /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata

# Create container startup script
RUN echo "#!/bin/bash\n\
    sudo service syslog-ng start\n\
    sudo service cron start\n\
    sudo service ssh start\n\
    sudo nginx -g 'daemon off;'\n\
    tail -f /var/log/nginx/access.log" > /start.sh && chmod +x /start.sh

# Run container start up script
CMD ["/bin/bash", "/start.sh"]
