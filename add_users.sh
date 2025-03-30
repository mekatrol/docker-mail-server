#!/bin/bash

DB_NAME="maildb"
GROUP_ID="1002"

# Define the CSV file
csv_file="/users.csv"

# Initialize a row counter
row_number=0

# Read the file, skipping the first line
tail -n +2 "$csv_file" | while IFS=, read -r email password display_name is_catchall; do
    ((row_number++))

    if [ -n "$email" ] && [ -n "$password" ] && [ -n "$is_catchall" ]; then
        echo "Row $row_number: email=$email, password=$password, display_name=$display_name, is catchall=$is_catchall"

        username="${email%@*}"
        domain="${email#*@}"

        # Add user email
        sudo -u postgres psql -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS pgcrypto; INSERT INTO users (email, password, realname, maildir) VALUES ('$email', '{BLF-CRYPT}' || crypt('$password', gen_salt('bf', 12)), '$display_name', '${domain//./_}_${username}/');"

        # Add alias
        sudo -u postgres psql -d $DB_NAME -c "INSERT INTO aliases (alias, email) VALUES ('$email', '$email');"

        # Add transport if not already exists
        sudo -u postgres psql -d $DB_NAME -c "INSERT INTO transports (domain, gid, transport) VALUES ('$domain', $GROUP_ID, 'virtual:') ON CONFLICT (domain) DO NOTHING;"

        # If is a catch ll then add catch all alias
        if [ $is_catchall == "y" ]; then
            echo "Setting $email as @$domain catch all"
            catch_all_configured=1
            sudo -u postgres psql -d $DB_NAME -c "INSERT INTO aliases (alias, email) VALUES ('@$domain', '$email');"
        fi
    else
        echo "Row $row_number does not contain 3 column values..."
    fi
done
