FROM rustlang/rust:nightly

# Set non-interactive mode for apt to avoid prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install required dependencies and setup Google Cloud SDK
RUN apt update && apt install -y \
    git \
    curl \
    build-essential \
    apt-transport-https \
    ca-certificates \
    gnupg \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && apt-get update -y \
    && apt-get install -y google-cloud-sdk \
    && rm -rf /var/lib/apt/lists/*

# Clone the plonky2 repository
RUN git clone https://github.com/mir-protocol/plonky2.git

# Update PATH to include Cargo
ENV PATH="/root/.cargo/bin:$PATH"

# Set environment variable for Rust flags
ENV RUSTFLAGS="-C target-cpu=native"

# Benchmark the plonky2 package
WORKDIR /plonky2

# Default CMD to run the benchmark
CMD ["cargo", "bench", "--package", "plonky2"]
