# ==============================
# Dockerfile for zkProof Builder 
# ==============================

FROM node:20-slim

# 1. Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential

# 2. Install Rust, Circom, SnarkJS (in einem Layer)
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y && \
    . "$HOME/.cargo/env" && \
    export PATH="$HOME/.cargo/bin:$PATH" && \
    cargo install --git https://github.com/iden3/circom.git --locked && \
    npm install -g snarkjs@latest

# 3. Prepare project files
WORKDIR /app
COPY circuits ./circuits
COPY inputs ./inputs
COPY scripts ./scripts
RUN git clone https://github.com/iden3/circomlib.git circuits/circomlib

# 4. Ensure PATH contains Cargo binaries
ENV PATH="/root/.cargo/bin:$PATH"
