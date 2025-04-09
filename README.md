# Benchmark automation tool

This tool allows users to schedule and run benchmarks for the Plonky2 zk-SNARK library on Google Cloud Platform (GCP). The benchmarks are executed using Docker containers on GCP VMs, and the results are uploaded to Google Cloud Storage (GCS) for later retrieval and analysis.

## Features

- Automatically provisions a GCP VM instance with the required configuration.
- Runs the `plonky2` benchmark using Docker.
- Stores benchmark logs in GCS.
- Lightweight and modular design using scripts and Docker.

---

## File structure

```plaintext
benchmark-tool/
├── benchmark_gui.py              # Python GUI using GCP APIs
├── Dockerfile                    # Docker file for building the Rust environment with dependencies
├── README.md                     # Documentation
├── setupvm/                      # Folder containing setup_vm related scripts
│   └── setup_vm.sh               # Script to create a VM
├── startup/                      # Folder containing startup related scripts
│   └── startup_script.sh         # Startup script that configures VM, installs dependencies, and schedules cron job
└── scripts/                      # Folder for any additional scripts
    └── benchmark_execution.sh    # Script that runs the benchmark and uploads the result to GCS
```

---

## Prerequisites

Before using this tool, ensure you have the following:

### Google Cloud Platform setup

### GCP setup

1. **Enable APIs:** Ensure the following APIs are enabled in GCP project:
   - Compute Engine API
   - Cloud Storage API
   - Cloud IAM API
   - Artifact Registry API

2. **GCP CLI installed:** Install and configure the GCP CLI and Docker on local machine:
   ```bash
   gcloud auth login
   gcloud config set project <project-id>
   ```

   [Installation Guide](https://cloud.google.com/sdk/docs/install).

3. **Permissions:** GCP account must have sufficient IAM permissions:
   - `roles/compute.admin`
   - `roles/storage.admin`

4. **Set up an Artifact Registry**:
   Create a repository:
   ```bash
   gcloud artifacts repositories create plonky2-repo \
       --repository-format=docker \
       --location=us-west1 \
       --description="Repository for Plonky2 benchmark Docker images"

   gcloud auth configure-docker us-west1-docker.pkg.dev
   ```

5. **Ensure the `setup_vm.sh` script is executable**:
   Create a repository:
   ```bash
   chmod +x setupvm/setup_vm.sh
   ```

### Install Python requirements
   ```bash
    pip install google-api-python-client google-auth google-cloud-storage
   ```

### Configure environment
Update the following in benchmark_gui.py:

   ```bash
    PROJECT = 'your-gcp-project-id'
    BUCKET_NAME = 'your-gcs-bucket'
   ```

---

## How to run the tool

### Step 1: Build the Docker image

Build the Docker image locally and push it to Artifact Registry:

1. Build the image:
   ```bash
   docker build -t us-west1-docker.pkg.dev/<project-id>/plonky2-repo/plonky2-benchmarker:1.0.0 .
   ```

2. Push the image to the Artifact Registry:
   ```bash
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
   ./setupvm/setup_vm.sh <INSTANCE_NAME> <MACHINE_TYPE> <CORES> <RAM>
   ```
   
   #### Parameters:
   - `<INSTANCE_NAME>`: Name of the VM instance (e.g., `benchmark-instance`).
   - `<MACHINE_TYPE>`: Type of machine. Use `custom` for custom configurations or predefined types like `e2-standard-2`.
   - `<CORES>`: Number of CPU cores, e.g., "2".
   - `<RAM>`: RAM, e.g., "8GB" or "8192MB".

   Modify the script variables as necessary:
   - `PROJECT_ID`
   - `ZONE`
  
   #### Example:
   - **Custom Machine**:
     ```bash
     ./setupvm/setup_vm.sh benchmark-instance custom 4 8192MB
     ```
   - **Predefined Machine**:
     ```bash
     ./setupvm/setup_vm.sh benchmark-instance e2-standard-2 2 8192MB
     ```
     
   This script sets up a VM in GCP and schedules the benchmark execution script.
   

### Step 4: Verify Logs

1. Navigate to GCS bucket to view the benchmark logs:
   ```bash
   gsutil ls gs://<bucket-name>/benchmark_output/<instance-name>
   ```

---


#### Overview:

## Tool Design

### Components

The tool leverages the following components:
- **Dockerfile**: A containerized environment to run Plonky2 benchmarks with Rust nightly and necessary dependencies pre-installed.
- **GCP VM**: Instances created dynamically to execute the benchmarks.
- **Startup script**: Automates the environment setup on the VM.
- **Benchmark execution script**: Runs the Dockerized benchmark and uploads the results to GCS.

#### Workflow:
1. `setup_vm.sh` creates a VM and sets up the startup script.
2. The startup script installs dependencies and schedules the `benchmark_execution.sh` script to run every 3 hours via cron.
3. `benchmark_execution.sh` pulls the Docker image, runs the benchmark, and uploads the log to GCS.

---


### Testing the Tool

#### Steps:
1. **Local test**:
   - Build and run the Docker container locally:
     ```bash
     docker build -t plonky2-bench .
     docker run --rm plonky2-bench
     ```
   - Ensure the benchmark runs successfully and produces output.

2. **GCP test**:
   - Run the `setup_vm.sh` script with a test configuration:
     ```bash
     ./setupvm/setup_vm.sh test-instance custom 2 2048MB
     ```
   - Verify that the VM is created and the startup script runs without errors.

3. **Check outputs**:
   - Navigate to the GCS bucket:
     ```bash
     gsutil ls gs://YOUR_BUCKET_NAME/
     ```
   - Verify the benchmark logs are uploaded.

## Notes

- Logs are stored in the GCS bucket under the path:
  ```
  gs://YOUR_BUCKET_NAME/<INSTANCE_NAME>/<DATE>/benchmark.log
  ```

- Ensure IAM permissions for the service account running the VM to access the GCS bucket and Artifact Registry.


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
     - `roles/compute.admin` (Cloud Build to create VMs).
       
   ```bash
   gcloud projects add-iam-policy-binding [PROJECT_ID] \
       --member="serviceAccount:[PROJECT_NUMBER]@cloudbuild.gserviceaccount.com" \
       --role="roles/artifactregistry.writer"
   ```

3. **Artifact Registry setup**:
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
    args: ["build", "-t", "us-west1-docker.pkg.dev/$PROJECT_ID/plonky2-repo/plonky2-benchmarker:1.0.0", "."]
  
  # Step 2: Push the Docker image to Artifact Registry
  - name: "gcr.io/cloud-builders/docker"
    args: ["push", "us-west1-docker.pkg.dev/$PROJECT_ID/plonky2-repo/plonky2-benchmarker:1.0.0"]

  # Step 3: Upload scripts to GCS
  - name: "gcr.io/cloud-builders/gsutil"
    args: ["cp", "scripts/benchmark_execution.sh", "gs://$GCS_BUCKET_NAME/scripts/benchmark_execution.sh"]

  - name: "gcr.io/cloud-builders/gsutil"
    args: ["cp", "startup_script.sh", "gs://$GCS_BUCKET_NAME/scripts/setup_vm_and_schedule.sh"]

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
  - "us-west1-docker.pkg.dev/$PROJECT_ID/plonky2-repo/plonky2-benchmarker:1.0.0"
```

### Triggering the build

1. **Create a trigger**:
   Use Cloud Build triggers to automate pipeline execution on code commits:
   ```bash
   gcloud beta builds triggers create github \
       --name="benchmark-tool-build" \
       --repo-name="repo-name" \
       --repo-owner="github-username" \
       --branch-pattern="^main$" \
       --build-config="cloudbuild.yaml"
   ```

2. **Test the trigger**:
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

## Known limitations

- The VM creation process assumes default network and firewall configurations.
- Benchmark scheduling frequency is fixed in the script (every 3 hours).

---

## Future improvements

- Add error handling to scripts.
- Implement a dynamic schedule configuration for benchmarks -> Event-driven execution: trigger benchmarks based on events such as receiving a Pub/Sub message or an API request. Due to some restrictions I'm not able to use Cloud Functions/Cloud Run at the moment.
- Integrate monitoring and alerting for failed benchmarks.

---

## Contact

Enjoy benchmarking with this tool! Let me know if there are any questions.
