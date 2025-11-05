# Quick Start Guide

## 🚀 Running the SaaS API Server

### Prerequisites

```r
# Install required packages
install.packages(c("plumber", "DBI", "RSQLite", "jsonlite", "digest", "base64enc"))

# Install the captcha package
remotes::install_github("jlmacedo/captcha")
```

### Start the Server

```r
# Load the package
library(captcha)

# Set environment variables (IMPORTANT!)
Sys.setenv(
  CAPTCHA_SECRET_KEY = "change_this_to_a_secure_64_character_random_string_in_production",
  CAPTCHA_ADMIN_KEY = "admin_secret_change_in_production",
  CAPTCHA_DB_PATH = "captcha_saas.db"
)

# Start the API server
source("inst/api/server.R")
start_captcha_api(host = "0.0.0.0", port = 8000)
```

The server will start at: **http://localhost:8000**

### Test the API

Open your browser and visit:
- Health Check: http://localhost:8000/health
- API Info: http://localhost:8000/
- API Docs: http://localhost:8000/__docs__/

### Create an API Key

```bash
curl -X POST http://localhost:8000/api/v1/admin/keys \
  -H "X-Admin-Key: admin_secret_change_in_production" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user_123",
    "name": "My Application",
    "tier": "pro",
    "monthly_limit": 100000
  }'
```

Response:
```json
{
  "success": true,
  "data": {
    "api_key": "captcha_xxxxxxxxxxxxxxxx",
    "user_id": "user_123",
    "tier": "pro",
    "monthly_limit": 100000
  }
}
```

**Save the API key!** You'll need it for SDK integration.

### Test Captcha Creation

```bash
curl -X POST http://localhost:8000/api/v1/captcha/create \
  -H "X-API-Key: captcha_xxxxxxxxxxxxxxxx" \
  -H "Content-Type: application/json" \
  -d '{"difficulty": "medium"}'
```

---

## 🌐 Web Integration (JavaScript)

### 1. Copy SDK Files

```bash
# Copy SDK to your web project
cp inst/sdks/javascript/captcha-sdk.js ./public/js/
cp inst/sdks/javascript/captcha-sdk.css ./public/css/
```

### 2. Add to Your HTML

```html
<!DOCTYPE html>
<html>
<head>
  <link rel="stylesheet" href="/css/captcha-sdk.css">
</head>
<body>
  <form id="loginForm">
    <input type="email" name="email" required>
    <input type="password" name="password" required>

    <!-- Captcha container -->
    <div id="captcha-container"></div>

    <button type="submit" id="submitBtn" disabled>Login</button>
  </form>

  <script src="/js/captcha-sdk.js"></script>
  <script>
    const captcha = new CaptchaSDK({
      apiKey: 'YOUR_API_KEY_HERE',
      apiUrl: 'http://localhost:8000',
      difficulty: 'medium',
      onSuccess: function(result) {
        console.log('Captcha verified!', result);
        document.getElementById('submitBtn').disabled = false;
      },
      onError: function(error) {
        console.error('Captcha error:', error);
        document.getElementById('submitBtn').disabled = true;
      }
    });

    captcha.render('#captcha-container');
  </script>
</body>
</html>
```

### 3. Test It

See complete example: `inst/sdks/javascript/examples/login-form.html`

---

## 📱 Flutter Integration

### 1. Add Dependency

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
```

### 2. Copy SDK

Copy `inst/sdks/flutter/lib/captcha_sdk.dart` to your project's `lib/` directory.

### 3. Use in Your App

```dart
import 'package:flutter/material.dart';
import 'captcha_sdk.dart';

class LoginPage extends StatelessWidget {
  final config = CaptchaConfig(
    apiKey: 'YOUR_API_KEY_HERE',
    apiUrl: 'http://localhost:8000',
    difficulty: CaptchaDifficulty.medium,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextField(/* email field */),
          TextField(/* password field */),

          CaptchaWidget(
            config: config,
            onSuccess: (captchaId, token) {
              print('Verified! Proceed with login');
              // Enable submit button
            },
          ),

          ElevatedButton(
            onPressed: () => submitForm(),
            child: Text('Login'),
          ),
        ],
      ),
    );
  }
}
```

### 4. Test It

See complete example: `inst/sdks/flutter/example/lib/main.dart`

---

## 🧪 Testing the Complete System

### 1. Start the API Server

```r
library(captcha)
Sys.setenv(CAPTCHA_SECRET_KEY = "test_key_64_chars")
source("inst/api/server.R")
start_captcha_api(port = 8000)
```

### 2. Create Test API Key

```bash
curl -X POST http://localhost:8000/api/v1/admin/keys \
  -H "X-Admin-Key: admin_secret_change_in_production" \
  -H "Content-Type: application/json" \
  -d '{"user_id":"test","name":"Test","tier":"pro","monthly_limit":10000}'
```

### 3. Open Example Page

```bash
# Open the login example in your browser
open inst/sdks/javascript/examples/login-form.html
```

**Note:** Replace `YOUR_API_KEY_HERE` with the actual API key from step 2.

### 4. Test the Flow

1. The page loads and displays a captcha
2. Solve the captcha (enter the text)
3. Click "Verify"
4. If correct, you'll see a success message
5. The submit button will be enabled

---

## 🐳 Docker Deployment (Production)

### 1. Build Docker Image

```dockerfile
# Dockerfile
FROM rocker/r-ver:4.3.0

RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libmagick++-dev

RUN R -e "install.packages(c('plumber', 'DBI', 'RSQLite', 'captcha'))"

WORKDIR /app
COPY . /app

EXPOSE 8000

CMD ["Rscript", "-e", "source('inst/api/server.R'); start_captcha_api()"]
```

### 2. Run with Docker Compose

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
      - CAPTCHA_ADMIN_KEY=${CAPTCHA_ADMIN_KEY}
    volumes:
      - ./data:/app/data
```

```bash
# Start
docker-compose up -d

# View logs
docker-compose logs -f

# Stop
docker-compose down
```

---

## 📊 Monitoring

### Check System Status

```bash
curl http://localhost:8000/api/v1/usage \
  -H "X-API-Key: YOUR_API_KEY"
```

### View Logs

```r
# In R console
library(DBI)
library(RSQLite)

db <- dbConnect(SQLite(), "captcha_saas.db")

# View recent usage
dbGetQuery(db, "
  SELECT * FROM usage_logs
  ORDER BY timestamp DESC
  LIMIT 10
")

# View API keys
dbGetQuery(db, "
  SELECT api_key, user_id, tier, monthly_usage, monthly_limit
  FROM api_keys
")

dbDisconnect(db)
```

---

## 🔧 Troubleshooting

### Issue: "API key required"

**Solution:** Make sure you're sending the API key in the header:
```javascript
headers: {
  'X-API-Key': 'your_api_key_here'
}
```

### Issue: CORS errors

**Solution:** The API server includes CORS headers by default. If you still have issues, check your browser console and ensure you're not using `file://` protocol (use a local web server instead).

### Issue: "Monthly usage limit exceeded"

**Solution:** Increase the limit for your API key:
```sql
UPDATE api_keys SET monthly_limit = 50000 WHERE api_key = 'your_key';
```

Or upgrade to a higher tier when creating the key.

### Issue: Port already in use

**Solution:** Change the port:
```r
start_captcha_api(port = 8080)
```

---

## 📚 Documentation

- **Complete SaaS Guide:** [SAAS.md](SAAS.md)
- **Security Best Practices:** [SECURITY.md](SECURITY.md)
- **API Examples:** [inst/examples/anti_ai_example.R](inst/examples/anti_ai_example.R)

---

## 🆘 Support

For issues or questions:
1. Check the documentation above
2. Review [SAAS.md](SAAS.md) for detailed guides
3. Check [GitHub Issues](https://github.com/jlmacedo/captcha/issues)

---

## ✅ Quick Checklist

- [ ] Install R packages (plumber, DBI, RSQLite, etc.)
- [ ] Set CAPTCHA_SECRET_KEY environment variable
- [ ] Start API server
- [ ] Create an API key via admin endpoint
- [ ] Copy API key to SDK configuration
- [ ] Test with browser example
- [ ] Integrate into your application
- [ ] Deploy to production (Docker/Kubernetes)
- [ ] Monitor usage and statistics

**You're all set!** 🎉
