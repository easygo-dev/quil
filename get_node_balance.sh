#!/bin/bash

cat << "EOF"
Processing...
EOF

sleep 5

SERVICE_FILE="/lib/systemd/system/ceremonyclient.service"
if [ ! -f "$SERVICE_FILE" ]; then
    echo "Error: The file $SERVICE_FILE does not exist. Ceremonyclient service setup failed."
    exit 1
fi

SCRIPT_DIR=~/scripts
SCRIPT_FILE=$SCRIPT_DIR/balance_check.sh
TEMP_SCRIPT_FILE=$SCRIPT_DIR/balance_check_temp.sh

check_command() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        sleep 1
        exit 1
    fi
}

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

echo "Creating script directory..."
sleep 1
mkdir -p $SCRIPT_DIR
check_command "Failed to create script directory"

echo "Creating temporary script..."
sleep 1
cat << EOF_SCRIPT >| $TEMP_SCRIPT_FILE
#!/bin/bash

# Function to extract node version
extract_node_version() {
    local version_info
    version_info=\$(journalctl -u ceremonyclient -r --no-hostname -n 1 -g "Quilibrium Node" -o cat)
    local version
    version=\$(echo "\$version_info" | grep -oP '(?<=Quilibrium Node - v)[0-9]+\.[0-9]+\.[0-9]+')
    local patch
    patch=\$(echo "\$version_info" | grep -oP '(?<=-p)[0-9]+')
    if [ -z "\$patch" ]; then
        echo "\$version"
    else
        echo "\$version.\$patch"
    fi
}

NODE_VERSION=\$(extract_node_version)
echo "Detected node version: \$NODE_VERSION"

NODE_CMD="cd ~/ceremonyclient/node && ./node-\${NODE_VERSION}-linux-$ARCH -node-info"
echo "NODE_CMD: \$NODE_CMD"

if [ ! -f "\$HOME/ceremonyclient/node/node-\${NODE_VERSION}-linux-$ARCH" ]; then
    echo "Error: Node binary does not exist"
    exit 1
fi

LOG_DIR=/root/scripts/log
LOG_FILE=\${LOG_DIR}/balance_check.log
CSV_FILE=\${LOG_DIR}/balance_check.csv
MAX_LOG_SIZE=10240

rotate_logs() {
    if [ -f "\${LOG_FILE}" ]; then
        local log_size_kb
        log_size_kb=\$(du -k "\${LOG_FILE}" | cut -f1)
        if [ "\${log_size_kb}" -ge "\${MAX_LOG_SIZE}" ]; then
            mv "\${LOG_FILE}" "\${LOG_FILE}.1"
            touch "\${LOG_FILE}"
        fi
    fi
}

mkdir -p \${LOG_DIR}
rotate_logs

current_output=\$(eval "\$NODE_CMD" 2>&1)
echo "current_output: \$current_output"

timestamp=\$(date '+%Y-%m-%d %H:%M:%S')

current_balance=\$(echo "\${current_output}" | grep "Owned balance:" | awk '{print \$3}')
echo "current_balance: \$current_balance"

if [ -f "\${CSV_FILE}" ]; then
    previous_balance=\$(tail -n 1 \${CSV_FILE} | cut -d ',' -f 2)
else
    previous_balance=0
    echo "Date,Current Balance,Previous Balance,Difference" > \${CSV_FILE}
    echo "\${timestamp},\${current_balance},0,0" >> \${CSV_FILE}
    echo "No previous balance found. CSV file created with current balance."
fi
echo "previous_balance: \$previous_balance"

if [ -z "\$current_balance" ]; then
    echo "\${timestamp} - Error: current balance is empty" | tee -a \${LOG_FILE}
    exit 1
fi

if [ -z "\$previous_balance" ]; then
    previous_balance=0
fi

balance_diff=\$(echo "\$current_balance - \$previous_balance" | bc)
echo "balance_diff: \$balance_diff"

echo "\${timestamp} - Previous balance: \${previous_balance} QUIL, Current balance: \${current_balance} QUIL, Difference: \${balance_diff} QUIL" | tee -a \${LOG_FILE}

echo "\${timestamp},\${current_balance},\${previous_balance},\${balance_diff}" >> \${CSV_FILE}
EOF_SCRIPT
check_command "Failed to create temporary script"

mv $TEMP_SCRIPT_FILE $SCRIPT_FILE
check_command "Failed to move temporary script to final script location"

echo "Making the script executable..."
sleep 1
chmod +x $SCRIPT_FILE
check_command "Failed to make script executable"

echo "⌛️ Checking if cron job exists..."
sleep 1
if crontab -l | grep -q "$SCRIPT_FILE"; then
    echo "Cron job already exists. Skipping..."
else
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
