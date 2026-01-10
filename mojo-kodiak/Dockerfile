FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip3 install psutil pyarrow

# Set working directory
WORKDIR /app

# Copy source code
COPY src/ ./src/
COPY .venv/ ./venv/

# Build the database (assuming Mojo is available)
# For now, assume pre-built binaries
COPY main ./main
COPY repl ./repl

# Expose port if needed
# EXPOSE 8080

# Run the REPL by default
CMD ["./repl"]