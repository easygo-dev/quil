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
SCRIPT_FILE=$SCRIPT_DIR/node_checker.sh
TEMP_SCRIPT_FILE=$SCRIPT_DIR/node_checker_temp.sh

# Function to check if a command succeeded
check_command() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        sleep 1
        exit 1
    fi
}

# Function to find the path to grpcurl
find_grpcurl_path() {
    GRPCURL_PATH=$(which grpcurl)
    check_command "Failed to find grpcurl with which command"
    echo $GRPCURL_PATH
}

# Create the scripts directory if it doesn't exist
echo "Creating script directory..."
sleep 1
mkdir -p $SCRIPT_DIR
check_command "Failed to create script directory"

# Find the path to grpcurl
GRPCURL_PATH=$(find_grpcurl_path)
echo "Found grpcurl at: $GRPCURL_PATH"

# Create the temporary script with the path to grpcurl
echo "Creating temporary script with grpcurl path..."
sleep 1
cat << EOF_TEMP >| $TEMP_SCRIPT_FILE
GRPCURL_PATH="$GRPCURL_PATH"
EOF_TEMP
check_command "Failed to create temporary script with grpcurl path"

# Create or overwrite the final script
echo "Creating or overwriting final script..."
sleep 1
cat << 'EOF_SCRIPT' >> $TEMP_SCRIPT_FILE
#!/bin/bash

# check with that cmd
CHECK_COMMAND="${GRPCURL_PATH} -plaintext localhost:8337 quilibrium.node.node.pb.NodeService.GetNetworkInfo"

# log
LOG_DIR=/root/scripts/log
LOG_FILE=${LOG_DIR}/node_check.log
MAX_LOG_SIZE=10240

# rotate
rotate_logs() {
    if [ -f "${LOG_FILE}" ]; then
        local log_size_kb=$(du -k "${LOG_FILE}" | cut -f1)
        if [ "${log_size_kb}" -ge "${MAX_LOG_SIZE}" ]; then
            mv "${LOG_FILE}" "${LOG_FILE}.1"
            touch "${LOG_FILE}"
        fi
    fi
}

# making dir
mkdir -p ${LOG_DIR}

# rotate
rotate_logs

# command
output=$(${CHECK_COMMAND} 2>&1)

# log
timestamp=$(date '+%Y-%m-%d %H:%M:%S')

# check errors in result
if echo "${output}" | grep -q "Failed to dial target host"; then
    echo "${timestamp} - Error detected: restarting node" | tee -a ${LOG_FILE}
    sudo service ceremonyclient restart | tee -a ${LOG_FILE}
    if [ $? -ne 0 ]; then
        echo "${timestamp} - Failed to restart ceremonyclient service." | tee -a ${LOG_FILE}
    else
        echo "${timestamp} - Ceremonyclient service restarted successfully." | tee -a ${LOG_FILE}
    fi
else
    echo "${timestamp} - Node is running correctly" | tee -a ${LOG_FILE}
fi
EOF_SCRIPT

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
    # Create a cron job to run the script every 16 minutes
    echo "⌛️ Setting up cron job..."
    sleep 1
    if (crontab -l 2>/dev/null; echo "*/16 * * * * $SCRIPT_FILE >> /root/scripts/node_checker_cron.log 2>&1") | crontab -; then
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
