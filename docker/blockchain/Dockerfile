# --------------------------------------------------------------------------
# STAGE 1: Use official polygon-edge image to retrieve the polygon-edge binary
# --------------------------------------------------------------------------
FROM 0xpolygon/polygon-edge:latest AS builder

# We don't need to do anything else here—just keep the binary from this image.

# --------------------------------------------------------------------------
# STAGE 2: Actual runtime container with bash installed
# --------------------------------------------------------------------------
FROM ubuntu:22.04

# Ensure system is up to date and install bash (usually included),
# plus any additional packages you need
RUN apt-get update && apt-get install -y ca-certificates bash && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create a working directory
WORKDIR /app

# Copy polygon-edge binary from the builder stage
COPY --from=builder /usr/local/bin/polygon-edge /usr/local/bin/polygon-edge
# If the binary is located elsewhere in the base image, adjust accordingly

# Copy your run script
COPY docker/blockchain/run_polygon_edge.sh /app/run_polygon_edge.sh

# Make it executable
RUN chmod +x /app/run_polygon_edge.sh

# Expose any ports needed for your multi-node setup
EXPOSE 10000 10001 10002 

# Finally, run the script with bash
CMD ["/bin/bash", "/app/run_polygon_edge.sh"]

