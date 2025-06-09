FROM python:3.9-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY docker/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/
COPY docker/entrypoint.py .
COPY docker/notifier.py .
COPY docker/s3_uploader.py .
COPY docker/config.json .

# Create data directories
RUN mkdir -p /app/data/raw_html /app/data/extracted /app/data/logs

# Environment variables
ENV PYTHONUNBUFFERED=1
ENV CONTAINER_ID=1
ENV URL_CHUNK_START=0
ENV URL_CHUNK_SIZE=5000

# Run the extraction process
CMD ["python", "entrypoint.py"]