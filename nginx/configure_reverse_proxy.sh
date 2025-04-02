#!/bin/bash

CONFIG_FILE="/etc/nginx/sites-available/reverse_proxy"
ENABLED_CONFIG="/etc/nginx/sites-enabled/reverse_proxy"
INPUT_FILE="reverse_proxy_list.txt"

# Check if input file exists
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file '$INPUT_FILE' not found!"
    exit 1
fi

# Create the Nginx configuration file
cat >"$CONFIG_FILE" <<EOF
# Nginx reverse proxy configuration
EOF

# Read input file and generate reverse proxy entries
while IFS=' ' read -r HOSTNAME IP_ADDRESS || [[ -n "$HOSTNAME" ]]; do
    if [[ -n "$HOSTNAME" && -n "$IP_ADDRESS" ]]; then
        cat >>"$CONFIG_FILE" <<EOF
    server {
        listen 80;
        server_name $HOSTNAME;

        location / {
            proxy_pass http://$IP_ADDRESS;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
    
EOF
    fi

done <"$INPUT_FILE"

# Enable the configuration
ln -sf "$CONFIG_FILE" "$ENABLED_CONFIG"
