# Anti-AI Captcha SDKs

Official client SDKs for integrating Anti-AI Captcha into your applications.

## 📦 Available SDKs

### 🌐 JavaScript/Web SDK

**Location:** `javascript/`

**Features:**
- Drop-in widget for websites
- Responsive design (mobile-friendly)
- Light and dark themes
- Behavioral tracking (mouse, keyboard)
- Auto-refresh on expiry
- Event callbacks

**Files:**
- `captcha-sdk.js` - Main SDK (500+ lines)
- `captcha-sdk.css` - Styling
- `examples/login-form.html` - Complete example

**Integration:**
```html
<link rel="stylesheet" href="captcha-sdk.css">
<script src="captcha-sdk.js"></script>

<div id="captcha"></div>

<script>
  new CaptchaSDK({
    apiKey: 'YOUR_API_KEY',
    apiUrl: 'https://your-api.com'
  }).render('#captcha');
</script>
```

**Use Cases:**
- Login forms
- Registration forms
- Password recovery
- Contact forms
- Comment submission

---

### 📱 Flutter SDK

**Location:** `flutter/`

**Features:**
- Cross-platform (iOS, Android, Web, Desktop)
- Native Material Design
- Theme support
- Async/await API
- Auto-refresh

**Files:**
- `lib/captcha_sdk.dart` - Main SDK (600+ lines)
- `example/lib/main.dart` - Complete example app

**Integration:**
```dart
import 'captcha_sdk.dart';

CaptchaWidget(
  config: CaptchaConfig(
    apiKey: 'YOUR_API_KEY',
    apiUrl: 'https://your-api.com',
  ),
  onSuccess: (id, token) {
    // Proceed with form submission
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

---

## 🚀 Getting Started

### 1. Start API Server

```r
library(captcha)
source("inst/api/server.R")
start_captcha_api()
```

### 2. Create API Key

```bash
curl -X POST http://localhost:8000/api/v1/admin/keys \
  -H "X-Admin-Key: admin_secret" \
  -d '{"user_id":"user1","tier":"pro"}'
```

### 3. Use SDK

See platform-specific examples above.

---

## 📖 Documentation

- **Quick Start:** [/QUICKSTART.md](../../QUICKSTART.md)
- **Complete SaaS Guide:** [/SAAS.md](../../SAAS.md)
- **Security:** [/SECURITY.md](../../SECURITY.md)

---

## 🔧 Configuration

All SDKs support the following configuration:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `apiKey` | string | **required** | Your API key |
| `apiUrl` | string | **required** | API server URL |
| `difficulty` | string | `"medium"` | Difficulty level (easy/medium/hard/extreme) |
| `theme` | string | `"light"` | UI theme (light/dark) |
| `onSuccess` | function | - | Called when captcha is verified |
| `onError` | function | - | Called on error |
| `onExpire` | function | - | Called when captcha expires |

---

## 🎨 Customization

### JavaScript SDK

```javascript
const captcha = new CaptchaSDK({
  apiKey: 'YOUR_KEY',
  apiUrl: 'https://api.example.com',
  difficulty: 'hard',
  theme: 'dark',
  onSuccess: (result) => {
    console.log('Verified!', result);
    // Enable form submission
  },
  onError: (error) => {
    console.error('Error:', error);
    // Show error message
  },
  onExpire: () => {
    console.log('Captcha expired');
    // Disable form submission
  }
});

captcha.render('#container', {
  collectBehavior: true,
  useProgressive: true
});
```

### Flutter SDK

```dart
CaptchaWidget(
  config: CaptchaConfig(
    apiKey: 'YOUR_KEY',
    apiUrl: 'https://api.example.com',
    difficulty: CaptchaDifficulty.hard,
    theme: CaptchaTheme.dark,
  ),
  difficulty: CaptchaDifficulty.hard,
  useProgressive: true,
  onSuccess: (captchaId, token) {
    print('Verified: $captchaId');
  },
  onError: (error) {
    print('Error: $error');
  },
  onExpire: () {
    print('Expired');
  },
)
```

---

## 🔒 Security Best Practices

### DO:
- ✅ Store API keys securely (environment variables)
- ✅ Use HTTPS in production
- ✅ Implement rate limiting on your backend
- ✅ Verify tokens on your server
- ✅ Use progressive difficulty for repeated failures
- ✅ Monitor usage statistics

### DON'T:
- ❌ Hardcode API keys in client code
- ❌ Use HTTP in production
- ❌ Trust client-side verification alone
- ❌ Store captcha solutions
- ❌ Bypass token validation

---

## 📊 Usage Examples

### Login Form (JavaScript)

```html
<form id="login">
  <input type="email" required>
  <input type="password" required>
  <div id="captcha"></div>
  <button type="submit" disabled id="submit">Login</button>
</form>

<script>
const captcha = new CaptchaSDK({
  apiKey: 'KEY',
  apiUrl: 'https://api.example.com',
  onSuccess: () => {
    document.getElementById('submit').disabled = false;
  }
});
captcha.render('#captcha');

document.getElementById('login').addEventListener('submit', async (e) => {
  e.preventDefault();

  const response = await fetch('/api/login', {
    method: 'POST',
    body: JSON.stringify({
      email: email.value,
      password: password.value,
      captcha_token: captcha.getToken(),
      captcha_id: captcha.getCaptchaId()
    })
  });

  // Handle response...
});
</script>
```

### Registration Form (Flutter)

```dart
class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _canSubmit = false;
  String? _captchaToken;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextField(/* email */),
          TextField(/* password */),

          CaptchaWidget(
            config: CaptchaConfig(
              apiKey: 'KEY',
              apiUrl: 'https://api.example.com',
            ),
            onSuccess: (captchaId, token) {
              setState(() {
                _captchaToken = token;
                _canSubmit = true;
              });
            },
          ),

          ElevatedButton(
            onPressed: _canSubmit ? _register : null,
            child: Text('Register'),
          ),
        ],
      ),
    );
  }

  Future<void> _register() async {
    // Submit form with _captchaToken
  }
}
```

---

## 🆘 Troubleshooting

### JavaScript SDK

**Issue:** "Cannot read property 'render' of undefined"

**Solution:** Make sure SDK is loaded before calling:
```html
<script src="captcha-sdk.js"></script>
<script>
  // SDK is now available as CaptchaSDK
</script>
```

**Issue:** CORS errors

**Solution:** API server includes CORS headers. Ensure you're using HTTP/HTTPS (not file://).

---

### Flutter SDK

**Issue:** "No file or directory found"

**Solution:** Copy `captcha_sdk.dart` to your `lib/` directory.

**Issue:** HTTP not allowed on iOS

**Solution:** For development, add to `Info.plist`:
```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
```

Use HTTPS in production!

---

## 🔄 Updates

Check for SDK updates regularly:

```bash
# Get latest version
git pull origin main

# Update SDKs in your project
cp inst/sdks/javascript/* your-project/public/
```

---

## 💬 Support

- **Documentation:** [/SAAS.md](../../SAAS.md)
- **Examples:** See `examples/` directories
- **Issues:** [GitHub Issues](https://github.com/jlmacedo/captcha/issues)

---

## 📝 License

MIT License - See [/LICENSE](../../LICENSE)

---

## 🎉 Ready to Go!

Choose your platform and start integrating:

- **Web:** Use JavaScript SDK
- **Mobile (iOS/Android):** Use Flutter SDK
- **React/Vue/Angular:** Use JavaScript SDK with framework wrappers
- **Native iOS/Android:** Coming soon!

Happy coding! 🚀
