#!/bin/bash

# Determine the path to grpcurl
echo "Determining path to grpcurl..."
GRPCURL_PATH=$(which grpcurl)
if [ -z "$GRPCURL_PATH" ]; then
    echo "grpcurl not found in PATH"
    exit 1
fi
echo "Found grpcurl at: $GRPCURL_PATH"

# Command to check the node status
CHECK_COMMAND="$GRPCURL_PATH -plaintext localhost:8337 quilibrium.node.node.pb.NodeService.GetNetworkInfo"

# Path to log files
LOG_DIR=/root/scripts/log
LOG_FILE=$LOG_DIR/node_check.log
MAX_LOG_SIZE=10240 # Maximum log file size in kilobytes (10MB)

# Function to rotate logs
rotate_logs() {
    echo "Rotating logs if necessary..."
    if [ -f "$LOG_FILE" ]; then
        local log_size_kb=$(du -k "$LOG_FILE" | cut -f1)
        echo "Log size: $log_size_kb KB"
        if [ "$log_size_kb" -ge "$MAX_LOG_SIZE" ]; then
            echo "Log file size exceeds maximum limit, rotating logs..."
            mv "$LOG_FILE" "$LOG_FILE.1"
            touch "$LOG_FILE"
        fi
    fi
}

# Create log directory if it does not exist
echo "Creating log directory if it does not exist..."
mkdir -p $LOG_DIR

# Rotate logs before writing
rotate_logs

# Execute the command and save the result
echo "Executing command: $CHECK_COMMAND"
output=$($CHECK_COMMAND 2>&1)
echo "Command executed."

# Check for errors in the result
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
if echo "$output" | grep -q "Failed to dial target host"; then
    echo "$timestamp - Error detected: restarting node" | tee -a $LOG_FILE
    sudo service ceremonyclient restart >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then
        echo "$timestamp - Failed to restart ceremonyclient service." | tee -a $LOG_FILE
    else
        echo "$timestamp - Ceremonyclient service restarted successfully." | tee -a $LOG_FILE
    fi
else
    echo "$timestamp - Node is running correctly" | tee -a $LOG_FILE
fi

