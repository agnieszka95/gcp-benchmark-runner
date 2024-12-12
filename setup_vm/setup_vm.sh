#!/bin/bash

# Variables
INSTANCE_NAME="$1"  # Instance name
MACHINE_TYPE="$2"    # e.g., "custom" or predefined type like "e2-standard-2"
CORES="$3"           # Number of CPU cores, e.g., "2"
RAM="$4"             # RAM, e.g., "8GB" or "8192MB"
PROJECT_ID="project_id"
ZONE="us-central1-a"

# Check if required arguments are provided
if [ -z "$INSTANCE_NAME" ] || [ -z "$MACHINE_TYPE" ] || [ -z "$CORES" ] || [ -z "$RAM" ]; then
    echo "Usage: $0 <INSTANCE_NAME> <MACHINE_TYPE> <CORES> <RAM>"
    echo "Example: $0 benchmark-instance custom 8 8192MB"
    exit 1
fi

# Validate CORES is a number
if ! [[ "$CORES" =~ ^[0-9]+$ ]]; then
    echo "Error: CORES must be a valid integer."
    exit 1
fi

# Validate RAM format (must be in GB or MB)
if ! [[ "$RAM" =~ ^[0-9]+(GB|MB)$ ]]; then
    echo "Error: RAM must be specified as a number followed by 'GB' or 'MB' (e.g., 8GB or 8192MB)."
    exit 1
fi

# Create VM based on machine type input
echo "Creating VM: $INSTANCE_NAME with $MACHINE_TYPE machine type, $CORES cores, and $RAM RAM..."

if [ "$MACHINE_TYPE" == "custom" ]; then
    # For custom machine types, use --custom-cpu and --custom-memory
    gcloud compute instances create $INSTANCE_NAME \
        --project=$PROJECT_ID \
        --zone=$ZONE \
        --custom-cpu=$CORES \
        --custom-memory=$RAM \
        --image-family=debian-11 \
        --image-project=debian-cloud \
        --boot-disk-size=20GB \
        --scopes=https://www.googleapis.com/auth/cloud-platform \
        --metadata=enable-oslogin=TRUE,startup-script-url=gs://bucket/scripts/startup_script.sh
else
    # For predefined machine types (e.g., e2-standard-2, n1-standard-4)
    gcloud compute instances create $INSTANCE_NAME \
        --project=$PROJECT_ID \
        --zone=$ZONE \
        --machine-type=$MACHINE_TYPE \
        --image-family=debian-11 \
        --image-project=debian-cloud \
        --boot-disk-size=20GB \
        --scopes=https://www.googleapis.com/auth/cloud-platform \
        --metadata=enable-oslogin=TRUE,startup-script-url=gs://bucket/scripts/startup_script.sh
fi

# Exponential Backoff for waiting for VM to initialize
echo "Waiting for VM to start..."

MAX_RETRIES=10
INITIAL_DELAY=5
RETRY_COUNT=0
DELAY=$INITIAL_DELAY

while true; do
    # Check if the VM is running
    VM_STATUS=$(gcloud compute instances describe $INSTANCE_NAME --project=$PROJECT_ID --zone=$ZONE --format="get(status)")

    if [ "$VM_STATUS" == "RUNNING" ]; then
        echo "VM is running!"
        break
    fi

    # Increment retry count and delay time (exponential backoff)
    RETRY_COUNT=$((RETRY_COUNT + 1))

    if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
        echo "VM initialization failed or timed out after $MAX_RETRIES attempts."
        exit 1
    fi

    echo "VM is not running yet. Retrying in $DELAY seconds..."
    sleep $DELAY

    # Exponentially increase the delay (double the previous delay)
    DELAY=$((DELAY * 2))
done

# Add the cron job to run benchmark_execution.sh every 3 hours for myuser
echo "*/3 * * * * $USER_HOME/benchmark/benchmark_execution.sh >> $USER_HOME/benchmark/benchmark_execution.log 2>&1" | crontab -u myuser -

# Output to verify cron job
echo "Cron job scheduled to run benchmark_execution.sh every 3 hours for myuser."
