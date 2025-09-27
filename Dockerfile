FROM python:3.11-slim

LABEL maintainer="wireguard-flask@example.com"
LABEL description="WireGuard Flask Client Generator"
LABEL version="1.0.0"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wireguard-tools \
    qrencode \
    curl \
    iproute2 \
    iptables \
    procps \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create app user (optional, for security)
RUN useradd -m -s /bin/bash appuser

# Create app directory
WORKDIR /app

# Copy requirements first for better Docker layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .
COPY static/ ./static/
COPY templates/ ./templates/
COPY scripts/ ./scripts/
COPY config/ ./config/

# Create necessary directories
RUN mkdir -p clients logs && \
    chmod +x scripts/*.sh

# Set environment variables
ENV FLASK_APP=app.py
ENV FLASK_ENV=production
ENV PYTHONPATH=/app
ENV WG_INTERFACE=wg0
ENV WG_NETWORK=10.0.0.0/24

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/ || exit 1

# Create entrypoint script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Check if WireGuard interface exists\n\
if ! ip link show $WG_INTERFACE >/dev/null 2>&1; then\n\
    echo "Warning: WireGuard interface $WG_INTERFACE not found"\n\
    echo "Make sure WireGuard is properly configured on the host"\n\
fi\n\
\n\
# Start the application\n\
exec python app.py' > /app/entrypoint.sh && \
    chmod +x /app/entrypoint.sh

# Switch to app user (uncomment for security)
# USER appuser

# Run application
CMD ["/app/entrypoint.sh"]