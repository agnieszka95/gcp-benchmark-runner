#!/bin/bash

# Create a new user if it doesn't already exist
if ! id -u myuser > /dev/null 2>&1; then
    useradd -m myuser
fi

# Install Cloud SDK
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
apt-get update -y
apt-get install -y google-cloud-sdk

# Copy benchmark_execution.sh
USER_HOME="/home/myuser"
mkdir -p $USER_HOME/benchmark
gsutil cp gs://benchmark-script-files/scripts/benchmark_execution.sh $USER_HOME/benchmark/
chmod +x $USER_HOME/benchmark/benchmark_execution.sh

# Install Docker and configure permissions
apt update
apt install -y docker.io
chmod 666 /var/run/docker.sock

# Add a cron job to run benchmark_execution.sh every 3 hours
echo "*/3 * * * * $USER_HOME/benchmark/benchmark_execution.sh >> $USER_HOME/benchmark/benchmark_execution.log 2>&1" | crontab -u myuser -

# Output to verify cron job
echo "Cron job scheduled to run benchmark_execution.sh every 3 hours."
