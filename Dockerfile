FROM python:3.10-slim

# Install system dependencies for Chrome and Selenium
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    unzip \
    curl \
    ca-certificates \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libwayland-client0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    xdg-utils \
    libu2f-udev \
    libvulkan1 \
    && rm -rf /var/lib/apt/lists/*

# Install Google Chrome
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# Install ChromeDriver (Selenium 4+ can auto-manage ChromeDriver, but we install it manually for reliability)
RUN CHROME_VERSION=$(google-chrome --version | awk '{print $3}') \
    && CHROME_MAJOR=$(echo $CHROME_VERSION | awk -F. '{print $1}') \
    && echo "Detected Chrome version: $CHROME_VERSION" \
    && CHROMEDRIVER_VERSION=$(curl -s "https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json" | python3 -c "import sys, json; data=json.load(sys.stdin); vs=[v['version'] for v in data['versions'] if v['version'].startswith('$CHROME_MAJOR.') and 'downloads' in v and 'chromedriver' in v['downloads']]; print(vs[-1] if vs else '')" 2>/dev/null || echo "") \
    && if [ -z "$CHROMEDRIVER_VERSION" ]; then \
        echo "Could not determine ChromeDriver version automatically, Selenium will manage it"; \
    else \
        echo "Installing ChromeDriver $CHROMEDRIVER_VERSION"; \
        wget -q "https://storage.googleapis.com/chrome-for-testing-public/${CHROMEDRIVER_VERSION}/linux64/chromedriver-linux64.zip" -O /tmp/chromedriver.zip || true; \
        if [ -f /tmp/chromedriver.zip ]; then \
            unzip -q /tmp/chromedriver.zip -d /tmp/ && \
            find /tmp -name chromedriver -type f -executable -exec mv {} /usr/local/bin/chromedriver \; && \
            chmod +x /usr/local/bin/chromedriver && \
            rm -rf /tmp/chromedriver*; \
        fi; \
    fi

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY app.py .
COPY templates/ templates/

# Create directories for downloads and cookies
RUN mkdir -p invoice_downloads

# Expose Flask port
EXPOSE 5001

# Set environment variables
ENV FLASK_APP=app.py
ENV FLASK_RUN_HOST=0.0.0.0
ENV FLASK_RUN_PORT=5001

# Run the application
CMD ["python", "-m", "flask", "run", "--host=0.0.0.0", "--port=5001"]
