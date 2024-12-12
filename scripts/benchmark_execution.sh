#!/bin/bash

# Variables
USER_HOME=$(eval echo ~)
BUCKET_NAME="bucket"
MACHINE_NAME=$(hostname)
DATE=$(date +%Y-%m-%d_%H-%M-%S)
FILE_PATH="$USER_HOME/benchmark/benchmark.log" 

# Create the benchmark directory if it doesn't exist
mkdir -p $USER_HOME/benchmark

# Log message
echo "Starting benchmark..."

# Run the benchmark using Docker
gcloud auth configure-docker us-west1-docker.pkg.dev --quiet
docker pull us-west1-docker.pkg.dev/agatest/plonky2-repo/plonky2-benchmarker:1.0.0 && docker run --rm -v $USER_HOME:/output us-west1-docker.pkg.dev/agatest/plonky2-repo/plonky2-benchmarker:1.0.0 > $FILE_PATH

# Upload the log to GCS
echo "Uploading benchmark log to GCS..."
gsutil cp $FILE_PATH gs://$BUCKET_NAME/$MACHINE_NAME/$DATE/benchmark.log
echo "Benchmark completed and uploaded successfully."
