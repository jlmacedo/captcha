# Anti-AI Captcha SaaS Platform

Complete documentation for deploying and using the Anti-AI Captcha as a SaaS service.

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Quick Start](#quick-start)
3. [API Server Deployment](#api-server-deployment)
4. [SDK Integration](#sdk-integration)
5. [Production Configuration](#production-configuration)
6. [Monitoring & Analytics](#monitoring--analytics)
7. [Pricing & Billing](#pricing--billing)
8. [Troubleshooting](#troubleshooting)

---

## 🏗️ Architecture Overview

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                         CLIENTS                              │
├──────────────────┬──────────────────┬───────────────────────┤
│   Web Browsers   │   Flutter Apps   │   Native Apps         │
│   (JavaScript)   │   (iOS/Android)  │   (Swift/Kotlin)      │
└────────┬─────────┴─────────┬────────┴──────────┬────────────┘
         │                   │                    │
         └───────────────────┼────────────────────┘
                            │
                    HTTPS/REST API
                            │
         ┌──────────────────┼──────────────────────┐
         │                  │                       │
    ┌────▼─────┐   ┌───────▼────────┐   ┌─────────▼────────┐
    │   Load   │   │   API Server   │   │  Rate Limiting   │
    │ Balancer │   │   (Plumber)    │   │  (Redis/Memory)  │
    └────┬─────┘   └───────┬────────┘   └─────────┬────────┘
         │                 │                       │
         └─────────────────┼───────────────────────┘
                          │
              ┌───────────┴───────────┐
              │                       │
      ┌───────▼────────┐     ┌───────▼────────┐
      │  Database      │     │  Storage       │
      │  (SQLite/PG)   │     │  (S3/Local)    │
      └────────────────┘     └────────────────┘
```

### Key Features

- **RESTful API**: Complete REST API with OpenAPI documentation
- **Multi-Platform SDKs**: JavaScript, Flutter, Android (Kotlin), iOS (Swift)
- **Secure Authentication**: API key-based authentication with rate limiting
- **Database Storage**: SQLite for development, PostgreSQL for production
- **Behavioral Analysis**: Mouse tracking, timing analysis, session history
- **Progressive Difficulty**: Automatic difficulty adjustment based on behavior
- **Usage Analytics**: Real-time statistics and monitoring

---

## 🚀 Quick Start

### 1. Start the API Server

```r
# Install dependencies
install.packages(c("plumber", "DBI", "RSQLite", "jsonlite"))

# Load the package
library(captcha)

# Set environment variables
Sys.setenv(
  CAPTCHA_SECRET_KEY = "your_64_character_secret_key_here",
  CAPTCHA_DB_PATH = "captcha_saas.db"
)

# Start server
source("inst/api/server.R")
start_captcha_api(host = "0.0.0.0", port = 8000)
```

Server will start at `http://localhost:8000`

### 2. Create an API Key

```bash
curl -X POST http://localhost:8000/api/v1/admin/keys \
  -H "X-Admin-Key: admin_secret" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user123",
    "name": "My App",
    "tier": "pro",
    "monthly_limit": 100000
  }'
```

Response:
```json
{
  "success": true,
  "data": {
    "api_key": "captcha_xxxxxxxxxxxx",
    "user_id": "user123",
    "tier": "pro",
    "monthly_limit": 100000
  }
}
```

### 3. Test the API

```bash
# Create captcha
curl -X POST http://localhost:8000/api/v1/captcha/create \
  -H "X-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"difficulty": "medium"}'

# Verify captcha
curl -X POST http://localhost:8000/api/v1/captcha/verify \
  -H "X-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "captcha_id": "...",
    "token": "...",
    "answer": "abc123",
    "solve_time": 8500
  }'
```

---

## 🌐 SDK Integration

### Web (JavaScript)

```html
<!DOCTYPE html>
<html>
<head>
  <link rel="stylesheet" href="captcha-sdk.css">
</head>
<body>
  <div id="captcha-container"></div>

  <script src="captcha-sdk.js"></script>
  <script>
    const captcha = new CaptchaSDK({
      apiKey: 'YOUR_API_KEY',
      apiUrl: 'https://your-api.com',
      difficulty: 'medium',
      onSuccess: function(result) {
        console.log('Verified!', result);
        // Enable form submission
      }
    });

    captcha.render('#captcha-container');
  </script>
</body>
</html>
```

**Use Cases:**
- Login forms
- Registration forms
- Password recovery
- Comment submission
- Contact forms
- Email verification

### Flutter (Mobile)

```dart
import 'package:captcha_sdk/captcha_sdk.dart';

final config = CaptchaConfig(
  apiKey: 'YOUR_API_KEY',
  apiUrl: 'https://your-api.com',
  difficulty: CaptchaDifficulty.medium,
);

// In your widget
CaptchaWidget(
  config: config,
  onSuccess: (captchaId, token) {
    print('Captcha verified!');
    // Proceed with form submission
  },
  onError: (error) {
    print('Error: $error');
  },
)
```

**Supported Platforms:**
- ✅ iOS 11.0+
- ✅ Android API 21+
- ✅ Web
- ✅ macOS
- ✅ Windows
- ✅ Linux

### Android (Kotlin) - Coming Soon

```kotlin
import com.captcha.sdk.CaptchaSDK

val captcha = CaptchaSDK.Builder()
    .apiKey("YOUR_API_KEY")
    .apiUrl("https://your-api.com")
    .difficulty(Difficulty.MEDIUM)
    .build()

captcha.show(activity) { result ->
    if (result.valid) {
        // Proceed with form submission
    }
}
```

### iOS (Swift) - Coming Soon

```swift
import CaptchaSDK

let config = CaptchaConfig(
    apiKey: "YOUR_API_KEY",
    apiUrl: "https://your-api.com",
    difficulty: .medium
)

CaptchaView(config: config) { result in
    if result.valid {
        // Proceed with form submission
    }
}
```

---

## 🚀 API Server Deployment

### Development Setup

```bash
# Clone repository
git clone https://github.com/your-org/captcha.git
cd captcha

# Install R dependencies
R -e "install.packages(c('plumber', 'DBI', 'RSQLite', 'captcha'))"

# Set environment variables
export CAPTCHA_SECRET_KEY="your_secret_key"
export CAPTCHA_DB_PATH="captcha.db"

# Run server
Rscript -e "source('inst/api/server.R'); start_captcha_api()"
```

### Production Deployment with Docker

```dockerfile
# Dockerfile
FROM rocker/r-ver:4.3.0

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libmagick++-dev \
    && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "install.packages(c('plumber', 'DBI', 'RSQLite', 'PostgreSQL', 'captcha'))"

# Copy application
WORKDIR /app
COPY inst/api/ /app/
COPY R/ /app/R/

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:8000/health || exit 1

# Start server
CMD ["Rscript", "-e", "source('server.R'); start_captcha_api(host='0.0.0.0', port=8000)"]
```

```yaml
# docker-compose.yml
version: '3.8'

services:
  captcha-api:
    build: .
    ports:
      - "8000:8000"
    environment:
      - CAPTCHA_SECRET_KEY=${CAPTCHA_SECRET_KEY}
      - CAPTCHA_DB_PATH=/data/captcha.db
      - CAPTCHA_ADMIN_KEY=${CAPTCHA_ADMIN_KEY}
    volumes:
      - ./data:/data
    restart: unless-stopped
    networks:
      - captcha-network

  postgres:
    image: postgres:15
    environment:
      - POSTGRES_DB=captcha
      - POSTGRES_USER=captcha
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - captcha-network
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    networks:
      - captcha-network
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - captcha-api
    networks:
      - captcha-network
    restart: unless-stopped

volumes:
  postgres-data:

networks:
  captcha-network:
```

### Kubernetes Deployment

```yaml
# kubernetes/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: captcha-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: captcha-api
  template:
    metadata:
      labels:
        app: captcha-api
    spec:
      containers:
      - name: captcha-api
        image: your-registry/captcha-api:latest
        ports:
        - containerPort: 8000
        env:
        - name: CAPTCHA_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: captcha-secrets
              key: secret-key
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 10
          periodSeconds: 5

---
apiVersion: v1
kind: Service
metadata:
  name: captcha-api-service
spec:
  selector:
    app: captcha-api
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8000
  type: LoadBalancer

---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: captcha-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: captcha-api
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `CAPTCHA_SECRET_KEY` | Secret key for token signing (64+ chars) | Yes | - |
| `CAPTCHA_DB_PATH` | Database file path | No | `captcha_saas.db` |
| `CAPTCHA_ADMIN_KEY` | Admin API key | Yes | - |
| `DATABASE_URL` | PostgreSQL connection string | No | - |
| `REDIS_URL` | Redis connection string | No | - |
| `PORT` | Server port | No | `8000` |
| `HOST` | Server host | No | `0.0.0.0` |

---

## ⚙️ Production Configuration

### Database Migration (SQLite to PostgreSQL)

```r
# Install PostgreSQL driver
install.packages("RPostgres")

# Migration script
library(DBI)
library(RSQLite)
library(RPostgres)

# Connect to SQLite
sqlite_con <- dbConnect(SQLite(), "captcha_saas.db")

# Connect to PostgreSQL
pg_con <- dbConnect(
  Postgres(),
  dbname = "captcha",
  host = "localhost",
  port = 5432,
  user = "captcha",
  password = Sys.getenv("DB_PASSWORD")
)

# Create tables in PostgreSQL
dbExecute(pg_con, "
  CREATE TABLE api_keys (
    api_key TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT,
    tier TEXT DEFAULT 'free',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    monthly_limit INTEGER DEFAULT 10000,
    monthly_usage INTEGER DEFAULT 0
  )
")

# Similar for other tables...

# Migrate data
api_keys <- dbReadTable(sqlite_con, "api_keys")
dbWriteTable(pg_con, "api_keys", api_keys, append = TRUE)

# Close connections
dbDisconnect(sqlite_con)
dbDisconnect(pg_con)
```

### NGINX Configuration

```nginx
# /etc/nginx/sites-available/captcha-api
upstream captcha_api {
    least_conn;
    server api1:8000 max_fails=3 fail_timeout=30s;
    server api2:8000 max_fails=3 fail_timeout=30s;
    server api3:8000 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    server_name api.captcha.example.com;

    # Redirect to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.captcha.example.com;

    # SSL Configuration
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
    limit_req zone=api_limit burst=20 nodelay;

    # Proxy to API servers
    location / {
        proxy_pass http://captcha_api;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Health check endpoint
    location /health {
        access_log off;
        proxy_pass http://captcha_api;
    }
}
```

### Monitoring with Prometheus

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'captcha-api'
    static_configs:
      - targets: ['captcha-api:8000']
    metrics_path: '/metrics'
    scrape_interval: 15s
```

---

## 📊 Monitoring & Analytics

### Real-Time Statistics

```r
# Get system status
status <- captcha_system_status(time_window_seconds = 86400)

# Output:
# Captcha System Status (Last 24 hours):
#   Total Attempts: 15234
#   Successful: 14567
#   Failed: 667
#   Success Rate: 95.6%
#   Avg Solve Time: 8.3 seconds
#   Unique Sessions: 3421
```

### Usage Dashboard

Access usage statistics via API:

```bash
curl -X GET http://localhost:8000/api/v1/usage?time_window=24 \
  -H "X-API-Key: YOUR_API_KEY"
```

Response:
```json
{
  "success": true,
  "data": {
    "api_usage": {
      "total_requests": 15234,
      "creates": 7850,
      "verifications": 7384,
      "successful": 14567,
      "failed": 667
    },
    "captcha_stats": {
      "total": 7850,
      "by_difficulty": [
        {"difficulty": "easy", "count": 1234},
        {"difficulty": "medium", "count": 4521},
        {"difficulty": "hard", "count": 1895},
        {"difficulty": "extreme", "count": 200}
      ]
    },
    "account_info": {
      "tier": "pro",
      "monthly_usage": 45678,
      "monthly_limit": 100000,
      "remaining": 54322
    }
  }
}
```

---

## 💰 Pricing & Billing

### Tier Structure

| Tier | Monthly Requests | Rate Limit | Price | Features |
|------|------------------|------------|-------|----------|
| **Free** | 10,000 | 10/hour | $0 | Basic features, community support |
| **Starter** | 100,000 | 100/hour | $29/mo | All difficulties, email support |
| **Pro** | 500,000 | 500/hour | $99/mo | Progressive difficulty, priority support |
| **Enterprise** | Unlimited | Custom | Custom | SLA, dedicated support, custom integration |

### Tracking Usage

```r
# Monthly usage tracking
library(DBI)

db <- get_db()

# Get monthly usage for all API keys
monthly_usage <- dbGetQuery(db, "
  SELECT
    api_key,
    user_id,
    tier,
    monthly_usage,
    monthly_limit,
    ROUND((monthly_usage * 100.0 / monthly_limit), 2) as usage_percent
  FROM api_keys
  WHERE is_active = 1
  ORDER BY usage_percent DESC
")

print(monthly_usage)
```

### Billing Integration (Stripe Example)

```r
# When usage exceeds limit
library(httr)

charge_customer <- function(user_id, amount, description) {
  POST(
    "https://api.stripe.com/v1/charges",
    authenticate(Sys.getenv("STRIPE_SECRET_KEY"), ""),
    body = list(
      amount = amount * 100, # cents
      currency = "usd",
      customer = user_id,
      description = description
    )
  )
}

# Check and charge overages
check_and_bill_overages <- function() {
  db <- get_db()

  overages <- dbGetQuery(db, "
    SELECT * FROM api_keys
    WHERE monthly_usage > monthly_limit
    AND tier != 'enterprise'
  ")

  for (i in 1:nrow(overages)) {
    key <- overages[i, ]
    overage_amount <- key$monthly_usage - key$monthly_limit
    charge_amount <- ceiling(overage_amount / 1000) * 0.10 # $0.10 per 1000

    charge_customer(
      key$user_id,
      charge_amount,
      sprintf("Overage charges: %d requests", overage_amount)
    )
  }
}
```

---

## 🔧 Troubleshooting

### Common Issues

#### 1. "API key required" Error

**Problem**: Missing or invalid API key

**Solution**:
```javascript
// Ensure API key is set
const captcha = new CaptchaSDK({
  apiKey: 'YOUR_ACTUAL_API_KEY', // Not 'YOUR_API_KEY'
  apiUrl: 'https://your-api.com'
});
```

#### 2. CORS Errors

**Problem**: Cross-origin requests blocked

**Solution**: Configure CORS in nginx or add to API server:
```nginx
add_header Access-Control-Allow-Origin "*" always;
add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
add_header Access-Control-Allow-Headers "Content-Type, X-API-Key" always;
```

#### 3. Rate Limit Exceeded

**Problem**: Too many requests from single session

**Solution**:
```r
# Increase rate limits for specific API key
db <- get_db()
dbExecute(db, "
  UPDATE api_keys
  SET monthly_limit = 50000
  WHERE api_key = ?
", params = list("captcha_xxx"))
```

#### 4. Database Lock Errors (SQLite)

**Problem**: Concurrent write conflicts

**Solution**: Migrate to PostgreSQL for production:
```r
# See "Database Migration" section above
```

#### 5. Slow Image Generation

**Problem**: ImageMagick performance

**Solution**:
```r
# Pre-generate captchas in background
generate_captcha_pool <- function(count = 100) {
  pool <- lapply(1:count, function(i) {
    captcha_generate_secure(difficulty = "medium")
  })

  saveRDS(pool, "captcha_pool.rds")
}

# Run periodically
generate_captcha_pool()
```

### Performance Tuning

```r
# Increase worker processes
library(future)
plan(multicore, workers = 8)

# Enable caching
library(cachem)
cache <- cache_disk("./cache")

# Cache captcha generation
cached_generate <- function(...) {
  cache$get_or_set(
    key = digest::digest(list(...)),
    value = captcha_generate_secure(...),
    ttl = 300
  )
}
```

---

## 📖 Additional Resources

- **API Documentation**: http://localhost:8000/docs
- **GitHub Repository**: https://github.com/your-org/captcha
- **Support**: support@captcha.example.com
- **Status Page**: https://status.captcha.example.com

---

## 🎓 Next Steps

1. **Deploy API Server**: Follow deployment guide above
2. **Create API Keys**: Use admin endpoint to generate keys
3. **Integrate SDKs**: Add captcha to your forms
4. **Monitor Usage**: Track statistics and set up alerts
5. **Scale**: Add load balancers and additional servers

For enterprise support and custom integration, contact: enterprise@captcha.example.com
