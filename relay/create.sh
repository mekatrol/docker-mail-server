#!/bin/bash

# e.g. to run this script:
# ADDITIONAL_MY_NETWORKS="192.168.0.0/24" \
# SSH_USER_NAME="ssh" \
# SSH_USER_PASSWORD="pwd" \
# HOSTNAME="mail.test.com" \
# MAIL_DOMAIN="test.com" \
# RELAY_TO="internalmail.test.com" \
# TIMEZONE="Australia/Sydney" \
# ./create.sh

if [ -z "$SSH_USER_NAME" ]; then
    echo "Error: SSH_USER_NAME must be defined!"
    exit 1
fi

if [ -z "$SSH_USER_PASSWORD" ]; then
    echo "Error: SSH_USER_PASSWORD must be defined!"
    exit 1
fi

if [ -z "$HOSTNAME" ]; then
    echo "Error: HOSTNAME must be defined!"
    exit 1
fi

if [ -z "$MAIL_DOMAIN" ]; then
    echo "Error: MAIL_DOMAIN must be defined!"
    exit 1
fi

if [ -z "$RELAY_TO" ]; then
    echo "Error: RELAY_TO must be defined!"
    exit 1
fi

if [ -z "$TIMEZONE" ]; then
    echo "Error: TIMEZONE must be defined!"
    exit 1
fi

if [ -z "$ADDITIONAL_MY_NETWORKS" ]; then
    echo "Error: ADDITIONAL_MY_NETWORKS must be defined!"
    exit 1
fi

# The name of the image that will be created with 'docker build'
IMAGE_NAME="mail-relay"

# The name of the container that will be created with docker run
CONTAINER_NAME="mail-relay"

# The name of the network the mail server will use
NETWORK_NAME="mail-server-network"

# The driver method used when creting the network if it does not already exist
NETWORK_DRIVER="ipvlan"

# The network interface card used for the network
NETWORK_PARENT="enp1s0"

# The network subnet
NETWORK_SUBNET="172.16.3.0/24"

# The network gateway
NETWORK_GATEWAY="172.16.3.1"

# Static IP address for the mail server host
CONTAINER_IP_ADDR="172.16.3.201"

# Mail server host name
CONTAINER_HOST_NAME="$HOSTNAME"

# The lets encrypt volume
LETS_ENCRYPT_VOLUME="/data/etc-letsencrypt:/etc/letsencrypt"

# Check if the network exists
if ! docker network ls --format '{{.Name}}' | grep -q "^$NETWORK_NAME$"; then
    echo "Network '$NETWORK_NAME' does not exist. Creating it..."
    docker network create --driver="$NETWORK_DRIVER" --subnet="$NETWORK_SUBNET" --gateway="$NETWORK_GATEWAY" -o parent="$NETWORK_PARENT" "$NETWORK_NAME"
else
    echo "Network '$NETWORK_NAME' already exists."
fi

if ! docker image ls --format '{{.Tag}}' | grep -q "^$IMAGE_NAME$"; then
    echo "Image '$IMAGE_NAME' does not exist. Creating it..."
    docker build -t "$IMAGE_NAME" \
        --build-arg ADDITIONAL_MY_NETWORKS="$ADDITIONAL_MY_NETWORKS"\
        --build-arg SSH_USER_NAME="$SSH_USER_NAME" \
        --build-arg SSH_USER_PASSWORD="$SSH_USER_PASSWORD" \
        --build-arg HOSTNAME="$HOSTNAME" \
        --build-arg MAIL_DOMAIN="$MAIL_DOMAIN" \
        --build-arg RELAY_TO="$RELAY_TO" \
        --build-arg TIMEZONE="$TIMEZONE" \
        .
else
    echo "Image '$IMAGE_NAME' already exists."
fi

docker run \
    -itd --network="$NETWORK_NAME" \
    --ip="$CONTAINER_IP_ADDR" \
    --name="$CONTAINER_NAME" \
    --hostname="$CONTAINER_HOST_NAME" \
    --volume="$LETS_ENCRYPT_VOLUME" \
    "$IMAGE_NAME"
