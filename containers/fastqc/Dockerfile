FROM ubuntu:20.04

# Prevent timezone prompt
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    tar \
    unzip \
    build-essential \
    python3 \
    python3-pip \
    default-jre \
    zip \
    awscli \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages for AWS access
RUN pip3 install boto3 awscli --upgrade

# Install FastQC
RUN wget https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v0.12.1.zip && \
    unzip fastqc_v0.12.1.zip && \
    chmod 755 FastQC/fastqc && \
    ln -s /FastQC/fastqc /usr/local/bin/fastqc

# Install AWS CLI v2 (more reliable)
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws/

# Create working directory
WORKDIR /data

# Create a proper entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Test that tools are installed
RUN fastqc --version && \
    python3 --version && \
    aws --version && \
    java -version

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
