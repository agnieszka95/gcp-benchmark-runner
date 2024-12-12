# Benchmark automation tool

This project automates the execution and logging of `plonky2` benchmarks on Google Cloud Platform (GCP). The tool schedules benchmark jobs to run on GCP virtual machines, collects output logs, and stores them in a Google Cloud Storage (GCS) bucket for retrieval and analysis.

## Features

- Automatically provisions a GCP VM instance with the required configuration.
- Runs the `plonky2` benchmark using Docker.
- Stores benchmark logs in GCS.
- Lightweight and modular design using scripts and Docker.

---

## File structure

```plaintext
benchmark-tool/
├── Dockerfile                    # Docker file for building the Rust environment with dependencies
├── README.md                     # Documentation
├── setup_vm/                     # Folder containing setup_vm related scripts
│   └── setup_vm.sh               # Script to create a VM
├── startup_script/               # Folder containing startup related scripts
│   └── startup_script.sh         # Startup script that configures VM, installs dependencies, and schedules cron job
└── scripts/                      # Folder for any additional scripts
    └── benchmark_execution.sh    # Script that runs the benchmark and uploads the result to GCS
```

---

## Prerequisites

Before using this tool, ensure you have the following:

### Google Cloud Platform setup

1. **Enable APIs:** Ensure the following APIs are enabled in GCP project:
   - Compute Engine API
   - Cloud Storage API
   - Cloud IAM API

2. **GCP CLI Installed:** Install and configure the GCP CLI on local machine:
   ```bash
   gcloud auth login
   gcloud config set project <project-id>
   ```

3. **Permissions:** GCP account must have sufficient IAM permissions:
   - `roles/compute.admin`
   - `roles/storage.admin`

### Environment Setup

- Install the following on local machine:
  - Bash
  - Google Cloud SDK (`gcloud`)
  - Docker

---

## How to run the tool

### Step 1: Build the Docker image

Build the Docker image locally and push it to Google Artifact Registry:

1. Build the image:
   ```bash
   docker build -t us-west1-docker.pkg.dev/<project-id>/plonky2-repo/plonky2-benchmarker:1.0.0 .
   ```

2. Push the image to the Artifact Registry:
   ```bash
   gcloud auth configure-docker us-west1-docker.pkg.dev
   docker push us-west1-docker.pkg.dev/<project-id>/plonky2-repo/plonky2-benchmarker:1.0.0
   ```

### Step 2: Upload benchmark execution script

1. Upload the `benchmark_execution.sh` script to a GCS bucket:
   ```bash
   gsutil cp scripts/benchmark_execution.sh gs://<bucket-name>/scripts/benchmark_execution.sh
   ```

### Step 3: Run the setup script

1. Execute the `setup_vm.sh` script to create the VM:
   ```bash
   chmod +x setup_vm/setup_vm_and_schedule.sh
   bash setup_vm.sh
   ```
   Modify the script variables as necessary:
   - `PROJECT_ID`
   - `ZONE`
  
  For a custom machine (e.g., 8 cores and 8192MB of RAM):
  ```bash
  ./setup_vm/setup_vm_and_schedule.sh benchmark-instance custom 8 8192MB
  ```

  This command will:

  Create a VM named benchmark-instance with a custom machine type. Configure the VM with 8 CPU cores and 8192MB of RAM.

  For a predefined machine (e.g., e2-standard-2):
  ```bash
  ./setup_vm/setup_vm_and_schedule.sh benchmark-instance e2-standard-2 2 8192MB
  ```

  This command will:

  Create a VM with the e2-standard-2 machine type. Configure the VM with 2 CPU cores and 8192MB of RAM.

2. The script will:
   - Create a VM instance.
   - Install Docker and set up a cron job to periodically run the benchmark.

### Step 4: Verify Logs

1. Navigate to GCS bucket to view the benchmark logs:
   ```bash
   gsutil ls gs://<bucket-name>/
   ```

---

## Tool Design

### Components

1. **Dockerfile**
   - Prepares a container with the Rust nightly toolchain and `plonky2` benchmarks.
   - Ensures consistency in the benchmark environment.
  
2. **startup_script.sh**
   - Configures the VM by creating a user (myuser), installs Google Cloud SDK and Docker, and schedules the benchmark_execution.sh script to run every 3 hours using cron.

3. **setup_vm.sh**
   - Accepts parameters for instance name, machine type, CPU cores, and RAM.
   - Creates a VM on GCP, attaches the startup script, and configures the VM to run the benchmark periodically.

4. **`benchmark_execution.sh`**
   - Executes the benchmark inside the Docker container.
   - Logs the output and uploads it to GCS.

### Workflow

1. **Setup**
   - The VM is provisioned and configured.
   - Docker is installed, and a benchmark script is scheduled.

2. **Execution**
   - The benchmark script runs periodically.
   - Output logs are collected and uploaded to GCS.

3. **Log Retrieval**
   - Logs are available in GCS for further analysis.

---

## Testing

### Local Testing

1. Build the Docker container locally:
   ```bash
   docker build -t plonky2-benchmarker .
   ```

2. Run the container to verify the benchmark:
   ```bash
   docker run --rm plonky2-benchmarker
   ```

### GCP Testing

1. Verify the VM is created successfully:
   ```bash
   gcloud compute instances list
   ```

2. Verify the benchmark script is running inside the VM:
   ```bash
   gcloud compute ssh <instance-name> --command "crontab -l"
   ```

3. Check for logs in the GCS bucket:
   ```bash
   gsutil ls gs://<bucket-name>/
   ```

---

## CI/CD for Cloud Build

### Prerequisites

1. **Enable Cloud Build API**:
   ```bash
   gcloud services enable cloudbuild.googleapis.com
   ```

2. **IAM Permissions**:
   - Grant the `Cloud Build` service account (`[PROJECT_NUMBER]@cloudbuild.gserviceaccount.com`) the following roles:
     - `roles/artifactregistry.writer` (to push Docker images).
     - `roles/storage.objectAdmin` (to upload scripts to GCS).
     - `roles/compute.admin` (if you want Cloud Build to create VMs).
   ```bash
   gcloud projects add-iam-policy-binding [PROJECT_ID] \
       --member="serviceAccount:[PROJECT_NUMBER]@cloudbuild.gserviceaccount.com" \
       --role="roles/artifactregistry.writer"
   ```

3. **Artifact Registry Setup**:
   Create a repository in Artifact Registry to store the Docker image:
   ```bash
   gcloud artifacts repositories create plonky2-repo \
       --repository-format=docker \
       --location=us-west1
   ```

### Cloud Build Configuration

Create a `cloudbuild.yaml` file in your repository:

```yaml
steps:
  # Step 1: Build the Docker image
  - name: "gcr.io/cloud-builders/docker"
    args: ["build", "-t", "us-west1-docker.pkg.dev/$PROJECT_ID/plonky2-repo/plonky2-benchmarker:latest", "."]
  
  # Step 2: Push the Docker image to Artifact Registry
  - name: "gcr.io/cloud-builders/docker"
    args: ["push", "us-west1-docker.pkg.dev/$PROJECT_ID/plonky2-repo/plonky2-benchmarker:latest"]

  # Step 3: Upload scripts to GCS
  - name: "gcr.io/cloud-builders/gsutil"
    args: ["cp", "scripts/benchmark_execution.sh", "gs://$GCS_BUCKET_NAME/scripts/benchmark_execution.sh"]

  - name: "gcr.io/cloud-builders/gsutil"
    args: ["cp", "setup_vm_and_schedule.sh", "gs://$GCS_BUCKET_NAME/scripts/setup_vm_and_schedule.sh"]

  # Step 4: (Optional) Create a VM to test the benchmark
  - name: "gcr.io/cloud-builders/gcloud"
    entrypoint: "bash"
    args:
      - "-c"
      - |
        gcloud compute instances create benchmark-instance \
          --project=$PROJECT_ID \
          --zone=us-central1-a \
          --machine-type=e2-micro \
          --image-family=debian-11 \
          --image-project=debian-cloud \
          --metadata=enable-oslogin=TRUE \
          --scopes=https://www.googleapis.com/auth/cloud-platform

substitutions:
  _GCS_BUCKET_NAME: "bucket-name"
  _PROJECT_ID: "project-id"
images:
  - "us-west1-docker.pkg.dev/$PROJECT_ID/plonky2-repo/plonky2-benchmarker:latest"
```

### Triggering the Build

1. **Create a Trigger**:
   Use Cloud Build triggers to automate pipeline execution on code commits:
   ```bash
   gcloud beta builds triggers create github \
       --name="benchmark-tool-build" \
       --repo-name="repo-name" \
       --repo-owner="github-username" \
       --branch-pattern="^main$" \
       --build-config="cloudbuild.yaml"
   ```

2. **Test the Trigger**:
   Push code to the `main` branch or trigger the build manually:
   ```bash
   gcloud builds submit --config cloudbuild.yaml
   ```

### Monitoring Cloud Build

- Use the Cloud Console to monitor builds:
  Navigate to **Cloud Build > History** to see the progress and logs of builds.

- Check logs for each step directly from the console or CLI:
  ```bash
  gcloud builds log [BUILD_ID]
  ```
---

## Known Limitations

- The VM creation process assumes default network and firewall configurations.
- Benchmark scheduling frequency is fixed in the script (every 30 minutes).

---

## Future Improvements

- Add error handling to scripts.
- Implement a dynamic schedule configuration for benchmarks -> Event-driven execution: trigger benchmarks based on events such as receiving a Pub/Sub message or an API request.
- Integrate monitoring and alerting for failed benchmarks.

---

## Contact

For questions or feedback, please reach out.
