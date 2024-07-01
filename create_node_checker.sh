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

# Overwrite the script if it already exists
echo "Creating or overwriting script..."
sleep 1
cat << EOF >| $SCRIPT_FILE
#!/bin/bash

# check with that cmd
CHECK_COMMAND="$GRPCURL_PATH -plaintext localhost:8337 quilibrium.node.node.pb.NodeService.GetNetworkInfo"

# log
LOG_DIR=/root/scripts/log
LOG_FILE=\$LOG_DIR/node_check.log
MAX_LOG_SIZE=10240

# rotate
rotate_logs() {
    if [ -f "\$LOG_FILE" ]; then
        local log_size_kb=\

