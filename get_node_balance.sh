#!/bin/bash

cat << "EOF"
Processing...
EOF

sleep 5 # add sleep time

# Check if ceremonyclient.service exists
SERVICE_FILE="/lib/systemd/system/ceremonyclient.service"
if [ ! -f "$SERVICE_FILE" ]; then
    echo "Error: The file $SERVICE_FILE does not exist. Ceremonyclient service setup failed."
    exit 1
fi

# Define variables
SCRIPT_DIR=~/scripts
SCRIPT_FILE=$SCRIPT_DIR/balance_check.sh
TEMP_SCRIPT_FILE=$SCRIPT_DIR/balance_check_temp.sh

# Function to check if a command succeeded
check_command() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        sleep 1
        exit 1
    fi
}

# Get CPU architecture
ARCH=$(uname -m)
if [ "$ARCH" == "x86_64" ]; then
    ARCH="amd64"
elif [ "$ARCH" == "aarch64" ]; then
    ARCH="arm64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi
echo "Detected architecture: $ARCH"

# Create the scripts directory if it doesn't exist
echo "Creating script directory..."
sleep 1
mkdir -p $SCRIPT_DIR
check_command "Failed to create script directory"

# Create the temporary script
echo "Creating temporary script..."
sleep 1
cat << EOF_SCRIPT >| $TEMP_SCRIPT_FILE
#!/bin/bash

# Function to extract node version
extract_node_version() {
    version_info=\$(journalctl -u ceremonyclient -r --no-hostname -n 1 -g "Quilibrium Node" -o cat)
    version=\$(echo \$version_info | grep -oP '(?<=Quilibrium Node - v)[0-9]+\.[0-9]+\.[0-9]+')
    patch=\$(echo \$version_info | grep -oP '(?<=-p)[0-9]+')
    echo "\$version.\$patch"
}

# Get node version
NODE_VERSION=\$(extract_node_version)
echo "Detected node version: \$NODE_VERSION"

# Define command to get node info
NODE_CMD="cd ~/ceremonyclient/node && ./node-\${NODE_VERSION}-linux-$ARCH -node-info"

# log
LOG_DIR=/root/scripts/log
LOG_FILE=\${LOG_DIR}/balance_check.log
PREV_LOG_FILE=\${LOG_DIR}/prev_balance_check.log
MAX_LOG_SIZE=10240

# rotate logs
rotate_logs() {
    if [ -f "\${LOG_FILE}" ]; then
        log_size_kb=\$(du -k "\${LOG_FILE}" | cut -f1)
        if [ "\${log_size_kb}" -ge "\${MAX_LOG_SIZE}" ]; then
            mv "\${LOG_FILE}" "\${LOG_FILE}.1"
            touch "\${LOG_FILE}"
        fi
    fi
}

# Create log directory
mkdir -p \${LOG_DIR}

# Rotate logs
rotate_logs

# Get current node info
current_output=\$(${NODE_CMD} 2>&1)

# Log timestamp
timestamp=\$(date '+%Y-%m-%d %H:%M:%S')

# Extract current balance
current_balance=\$(echo "\${current_output}" | grep -oP '(?<=Unclaimed balance: )[0-9]+\.[0-9]+')

# Read previous balance
if [ -f "\${PREV_LOG_FILE}" ]; then
    previous_balance=\$(cat \${PREV_LOG_FILE})
else
    previous_balance=0
fi

# Calculate balance difference
balance_diff=\$(echo "\$current_balance - \$previous_balance" | bc)

# Log balances and difference
echo "\${timestamp} - Previous balance: \${previous_balance} QUIL, Current balance: \${current_balance} QUIL, Difference: \${balance_diff} QUIL" | tee -a \${LOG_FILE}

# Save current balance for next run
echo "\${current_balance}" > \${PREV_LOG_FILE}

EOF_SCRIPT
check_command "Failed to create temporary script"

# Move the temporary script to the final script location
mv $TEMP_SCRIPT_FILE $SCRIPT_FILE
check_command "Failed to move temporary script to final script location"

# Make the script executable
echo "Making the script executable..."
sleep 1
chmod +x $SCRIPT_FILE
check_command "Failed to make script executable"

# Check if cron job already exists
echo "⌛️ Checking if cron job exists..."
sleep 1
if crontab -l | grep -q "$SCRIPT_FILE"; then
    echo "Cron job already exists. Skipping..."
else
    # Create a cron job to run the script every day at the same time
    echo "⌛️ Setting up cron job..."
    sleep 1
    if (crontab -l 2>/dev/null; echo "0 0 * * * $SCRIPT_FILE") | crontab -; then
        echo "Cron job created successfully."
        sleep 1
    else
        echo "Failed to create cron job. Please check your permissions."
        sleep 1
        exit 1
    fi
fi

echo "Installation complete. The monitoring script has been set up and the cron job has been created or skipped."
sleep 1
echo "You can find the monitoring script at: $SCRIPT_FILE"
sleep 1
echo "Logs will be written to: /root/scripts/log/"
sleep 1
