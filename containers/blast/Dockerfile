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
    awscli \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages for AWS access
RUN pip3 install boto3 awscli --upgrade

# Install latest NCBI BLAST+ (v2.15.0)
RUN wget https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.15.0/ncbi-blast-2.15.0+-x64-linux.tar.gz && \
    tar -xzf ncbi-blast-2.15.0+-x64-linux.tar.gz && \
    cp -r ncbi-blast-2.15.0+/bin/* /usr/local/bin/ && \
    rm -rf ncbi-blast-2.15.0+-x64-linux.tar.gz ncbi-blast-2.15.0+

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws/

# Create working directory
WORKDIR /data

# Create entrypoint script
COPY blast-entrypoint.sh /usr/local/bin/blast-entrypoint.sh
RUN chmod +x /usr/local/bin/blast-entrypoint.sh

# Test installations
RUN blastn -version && \
    python3 --version && \
    aws --version

ENTRYPOINT ["/usr/local/bin/blast-entrypoint.sh"]
