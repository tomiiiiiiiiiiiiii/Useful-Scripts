#!/bin/bash

###############################
# This script checks a list of domains and informs you which certificates are expiring soon.
# Written by T0mi [grlc.eu]
###############################

# Domain List
domains=(
         "wallet.grlc.eu" 
         "stock.pm"
         "ai9bot.com" 
         "grlc.eu"
        )

for domain in "${domains[@]}"; do
    # Get certificate information for a given domain
    certificate_info=$(openssl s_client -connect "$domain:443" </dev/null 2>/dev/null | openssl x509 -noout -dates)

    # Get certificate expiration date
    expiration_date=$(echo "$certificate_info" | awk -F '=' '/notAfter/{print $2}')
    
    # Convert certificate expiration date to human readable
    expiration_human_readable=$(date -d "$expiration_date" +"%Y-%m-%d %H:%M:%S")

    expiration_epoch=$(date -d "$expiration_date" +"%s")
    current_epoch=$(date +"%s")
    notification_period=$((14 * 24 * 3600))  # 14 days in seconds

    if [ "$expiration_epoch" -lt "$current_epoch" ]; then
        # Certificate expired - show in red
        echo -e "\e[31m$domain: Certificate has expired (valid until: $expiration_human_readable)\e[0m"
    elif [ "$expiration_epoch" -lt "$((current_epoch + notification_period))" ]; then
        # Certificate will expire in next 14 days - show in yellow
        echo -e "\e[33m$domain: The certificate will expire in the next 14 days (valid until: $expiration_human_readable)\e[0m"
    else
        # Certificate is valid - show in green
        echo -e "\e[32m$domain: The certificate is valid (valid until: $expiration_human_readable)\e[0m"
    fi
done
