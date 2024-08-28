#!/bin/bash

###############################
# A quick check of critical hard drive parameters and their status.
# Written by T0mi [grlc.eu]
###############################

SMARTCTL=$(which smartctl 2>/dev/null)

if [ -z "$SMARTCTL" ] || [ ! -x "$SMARTCTL" ]; then
    echo "smartmontools is not installed or executable. Please install it to proceed."
    exit 1
fi

function check_smart {
    local device="$1"
    local device_type="$2"
    local tmp=$(mktemp)
    local critical=false

    $SMARTCTL -A -d "$device_type" "$device" | sed -r 's/^\s+//g' > "$tmp"

    if [[ $device_type == "nvme" ]]; then
        # NVMe-specific attributes
        local critical_warning=$(grep -i "Critical Warning" "$tmp" | awk '{print $3}')
        local temperature=$(grep -i "Temperature" "$tmp" | awk '/Celsius/ {print $2}' | sed 's/[^0-9]//g')
        local available_spare=$(grep -i "Available Spare:" "$tmp" | awk '{print $3}' | tr -d '%')
        local percentage_used=$(grep -i "Percentage Used" "$tmp" | awk '{print $3}' | tr -d '%')
        local media_errors=$(grep -i "Media and Data Integrity Errors" "$tmp" | awk '{print $5}')
        
        # Error Information Log Entries
        local error_log_entries=$(grep -i "Error Information Log Entries" "$tmp" | awk '{print $5}')
        
        # Handle cases where the error_log_entries field might not be present or might have extra spaces
        if [[ -z "$error_log_entries" ]] || [[ ! "$error_log_entries" =~ ^[0-9]+$ ]]; then
            error_log_entries=$(grep -i "Error Information Log Entries" "$tmp" | awk '{print $NF}')
        fi

        # Display critical warning
        if [[ "$critical_warning" != "0x00" ]]; then
            echo -e "$device: Critical Warning: \033[31;1m$critical_warning\033[0m"
            critical=true
        else
            echo -e "$device: Critical Warning: \033[32;1m$critical_warning\033[0m"
        fi

        # Display temperature
        if [[ "$temperature" =~ ^[0-9]+$ ]]; then
            if [[ "$temperature" -ge 70 ]]; then
                echo -e "$device: Temperature: \033[31;1m$temperature Celsius (high)\033[0m"
                critical=true
            else
                echo -e "$device: Temperature: \033[32;1m$temperature Celsius (normal)\033[0m"
            fi
        else
            echo -e "$device: Temperature: \033[31;1mUnable to parse temperature\033[0m"
            critical=true
        fi

        # Display available spare
        if [[ "$available_spare" =~ ^[0-9]+$ ]] && [[ "$available_spare" -le 10 ]]; then
            echo -e "$device: Available Spare: \033[31;1m$available_spare%\033[0m"
            critical=true
        else
            echo -e "$device: Available Spare: \033[32;1m$available_spare%\033[0m"
        fi

        # Display percentage used
        if [[ "$percentage_used" =~ ^[0-9]+$ ]] && [[ "$percentage_used" -ge 80 ]]; then
            echo -e "$device: Percentage Used: \033[31;1m$percentage_used%\033[0m"
            critical=true
        else
            echo -e "$device: Percentage Used: \033[32;1m$percentage_used%\033[0m"
        fi

        # Display media and data integrity errors
        if [[ "$media_errors" =~ ^[0-9]+$ ]] && [[ "$media_errors" -ne 0 ]]; then
            echo -e "$device: Media and Data Integrity Errors: \033[31;1m$media_errors\033[0m"
            critical=true
        else
            echo -e "$device: Media and Data Integrity Errors: \033[32;1mNo errors\033[0m"
        fi

        # Display error information log entries
        if [[ "$error_log_entries" =~ ^[0-9]+$ ]] && [[ "$error_log_entries" -ne 0 ]]; then
            echo -e "$device: Error Information Log Entries: \033[31;1m$error_log_entries\033[0m"
            critical=true
        else
            echo -e "$device: Error Information Log Entries: \033[32;1mNo errors\033[0m"
        fi

    else
        # SATA/SAS-specific attributes
        local critical_attributes=(5 10 11 171 172 177 181 187 188 196 197 198 199 200 231)

        for attr_id in "${critical_attributes[@]}"; do
            local line=$(grep "^$attr_id " "$tmp" | awk '{ print $2, "=", $10 }')
            if [ -n "$line" ]; then
                local value=$(echo "$line" | awk '{ print $3 }')
                echo -n "$device: "
                if [ "$value" != 0 ]; then
                    echo -e "\033[31;1m$line\033[0m"
                    critical=true
                else
                    echo -e "\033[32;1m$line\033[0m"
                fi
            fi
        done
    fi

    echo
    rm -f "$tmp"
}

function check_3ware {
    local controller="$1"
    local unit="$2"
    check_smart "-d 3ware,$unit /dev/$controller" "3ware"
}

if [ $# -gt 0 ]; then
    devices="$@"
else
    devices=$(ls /dev/sd[a-z] 2>/dev/null)  # SATA/SAS devices
    devices="$devices $(ls /dev/nvme[0-9]n[0-9] 2>/dev/null)"  # NVMe devices
fi

echo

# Check for 3ware RAID controllers
if [ -b /dev/twe0 ]; then
    check_3ware "twe0" 0
    check_3ware "twe0" 1
elif [ -b /dev/twa0 ]; then
    check_3ware "twa0" 0
    check_3ware "twa0" 1
elif [ -b /dev/twl0 ]; then
    check_3ware "twl0" 0
    check_3ware "twl0" 1
elif [ -b /dev/twd0 ]; then
    check_3ware "twd0" 0
    check_3ware "twd0" 1
elif [ -b /dev/tws0 ]; then
    check_3ware "tws0" 0
    check_3ware "tws0" 1
else
    # Check each device (SATA/SAS and NVMe)
    for device in $devices; do
        if [[ $device == /dev/nvme* ]]; then
            check_smart "$device" "nvme"
        else
            check_smart "$device" "auto"
        fi
    done
fi
