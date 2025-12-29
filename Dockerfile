FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libpopt-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Build the C generator
RUN cd generator && gcc -O -D_GNU_SOURCE -o puzzlebox puzzlebox.c -lpopt -lm

# Expose port
EXPOSE 10000

# Set environment variable
ENV PORT=10000

# Run the application
CMD ["python3", "puzzlebox.py"]

