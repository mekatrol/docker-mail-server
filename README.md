# docker-mail-server

A docker container for postfix / dovecot mail server with postgres virtual mailboxes using lets encrypt for certificates.

## Server folder

> An email server Dockerfile to create a fully configured image.

## Relay folder

> Under developement. Not usable for now (or maybe forever!)...

## Running the Server

### Copy files

1.  add_users.sh - a script that can be executed to add email users and catch all addresses.
2.  create.sh - creates the Docker network, image and container then runs the server.
3.  destroy.sh - destroys the container and image (but not network). For quick cleanup while debuggin image / container creation.
4.  Dockerfile - the Dockerfile used to build the server image. This file contains all of the configuration for NGINX, Postfix, Dovecot, Postgres, etc
5.  user.csv - can be used to define the users, passwords and catch all addresses.

### Set variables

Modify the following `create.sh` variables to suit your preferences:

```bash
# The name of the image that will be created with 'docker build'
IMAGE_NAME="mail-server"

# The name of the container that will be created with docker run
CONTAINER_NAME="mail-server"

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
CONTAINER_IP_ADDR="172.16.3.200"

# Mail server host name
CONTAINER_HOST_NAME="$HOSTNAME"

# The lets encrypt volume
LETS_ENCRYPT_VOLUME="/data/etc-letsencrypt:/etc/letsencrypt"
```

\*\*\* NOTE: the docker volume is not created in these scripts, it must exist!

### Run `create.sh`

`create.sh` will create the Docker image and then run a container from that image. It needs to be run with the required variables, eg:

```bash
DB_NAME="maildb" \
POSTGRES_PASSWORD="postgress_pwd" \
DB_ADMIN_NAME="db_admin" \
DB_ADMIN_PASSWORD="admin_pwd" \
DB_READER_NAME="db_reader" \
DB_READER_PASSWORD="reader_pwd" \
SSH_USER_NAME="ssh" \
SSH_USER_PASSWORD="pwd" \
HOSTNAME="mail.test.com" \
MAIL_DOMAIN="test.com" \
TIMEZONE="Australia/Sydney" \
./create.sh
```

With:

> DB_NAME - the name of the 'mail' database to hold email addresses, aliases and transports.

> POSTGRES_PASSWORD - will be used to replace the default Postgres password (default is `postgres`)

> DB_ADMIN_NAME - the user name that has read and update permissions on the 'mail' database.

> DB_ADMIN_PASSWORD - the admin user password.

> DB_READER_NAME - the user name that has read-only permissions on the 'mail' database. This user is used to access the database in the context of authenticating a user as well as sending and receiving emails.

> DB_READER_PASSWORD - the reader user password.

> SSH_USER_NAME - the SSH user login (to allow remote SSH access to the running container).

> SSH_USER_PASSWORD - the SSH user password.

> HOSTNAME - the server hostname (e.g. smtp.test.com) (often important as it should match the PTR record for the server iP address).

> MAIL_DOMAIN - the email domain (e.g. test.com).

> TIMEZONE - the timezone for the server.

## Adding users

The `add_users.sh` and `users.csv` files are copied to the docker container during the image build.

The `users.csv` file allows you define a set of users to add to the server (including catch all email addresses).

The users are used to poluate the users, aliases and transports tables.

The followning `user.csv` example:

```csv
email,password,display_name,is_catchall
admin@test.com,pwd123,Admin,n
catchall@test.com,pwd456,Catch All,y
```

will create the users:

```bash
       email       |                                password                                 | realname  |      maildir
-------------------+-------------------------------------------------------------------------+-----------+--------------------
 admin@test.com    | {BLF-CRYPT}$2a$12$K/Pb96m6Zja7XIJLiDgUtOvpaqjuLL84eZfGZUuV/UyAh94fsWkt. | Admin     | test_com_admin/
 catchall@test.com | {BLF-CRYPT}$2a$12$uVaMvJa7HhlbF8Wj2TuTZurHt9qLp86Jlh47/ZkXiktGilqrhYTc2 | Catch All | test_com_catchall/
```

the following aliases:

```bash
       alias       |       email
-------------------+-------------------
 admin@test.com    | admin@test.com
 catchall@test.com | catchall@test.com
 @test.com         | catchall@test.com
```

and the following transports:

```bash
  domain  | gid  | transport
----------+------+-----------
 test.com | 1002 | virtual:
```
