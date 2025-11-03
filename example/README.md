# PVCache Example: TTL, Encryption & Selective Encryption

Example showing three types of caching with automatic expiration (TTL).

## What This Example Shows

**Regular Cache (Examples 1-6):**
- Data expires after set time
- No encryption - plain cached data

**Secure Cache (Examples 7-11):**
- Full encryption of entire object
- Auto-generated encryption key

**Selective Cache (Examples 12-16):**
- Encrypts only specified fields
- Rest of data remains readable

## Quick Start

```bash
dart run example/main.dart
```

## How to Use

### Regular Cache
```dart
final cache = CacheManager();

// Cache for 5 minutes
await cache.set('user_data', userData, ttlSeconds: 300);
final data = await cache.get('user_data');
```

### Secure Cache (full encryption)
```dart
// Entire object encrypted
await cache.setSecure('auth_token', token, ttlSeconds: 7200);
final token = await cache.getSecure('auth_token');
```

### Selective Cache (field-level encryption)
```dart
// Only encrypt sensitive fields
await cache.setSelective(
  'user:123',
  {
    'name': 'John',           // readable
    'email': 'john@example.com', // readable
    'password': 'secret',      // encrypted
    'ssn': '123-45-6789',     // encrypted
  },
  secureFields: ['password', 'ssn'],
  ttlSeconds: 300,
);

final user = await cache.getSelective('user:123');
// password and ssn auto-decrypted
```

## When to Use Each

**Regular Cache:**
- Public data (profiles, configs)
- Performance-critical
- Debugging-friendly

**Secure Cache:**
- Entire object is sensitive
- Auth tokens, credentials
- Simple use case

**Selective Cache:**
- Mixed sensitivity data
- Need to query/debug non-sensitive fields
- Optimize encryption overhead
- Example: User object with password field

## File Structure

```
example/
├── main.dart              # Examples 1-16
├── cache_manager.dart     # All three cache types
├── models/user.dart       # Data model
└── services/user_service.dart  # Service layer
```

## Selective Encryption Examples

### User Data (encrypt password + SSN)
```dart
await cache.setSelective(
  'user:123',
  userData,
  secureFields: ['password', 'profile.ssn'],
);
```

### API Config (encrypt keys only)
```dart
await cache.setSelective(
  'config:stripe',
  {
    'service': 'stripe',      // readable
    'apiKey': 'sk_live...',   // encrypted
    'webhookSecret': '...',   // encrypted
  },
  secureFields: ['apiKey', 'webhookSecret'],
);
```

### Session (encrypt tokens)
```dart
await cache.setSelective(
  'session:user_123',
  sessionData,
  secureFields: ['tokens.access', 'tokens.refresh', 'mfaCode'],
);
```

### Nested Fields (dot notation)
```dart
secureFields: [
  'password',              // top-level
  'profile.ssn',          // nested in profile
  'tokens.0.value',       // array index
  'auth.api.secret',      // deeply nested
]
```

## How It Works

**TTL:** Data expires after set seconds → returns `null` when expired

**Full Encryption:** Entire object → JSON → Encrypt → Store

**Selective Encryption:**
- Each field gets unique nonce
- Only specified fields encrypted
- Nonces stored in metadata
- Dot notation for nested fields

## Tips

```dart
// Different TTLs for different data
await cache.set('hot', data, ttlSeconds: 10);      // 10 sec
await cache.set('warm', data, ttlSeconds: 300);    // 5 min
await cache.set('cold', data, ttlSeconds: 3600);   // 1 hour

// No TTL = permanent
await cache.set('user_id', id);

// Selective encryption best practices
secureFields: [
  'password',        // ✓ Always encrypt credentials
  'ssn',            // ✓ Encrypt PII
  'cardNumber',     // ✓ Encrypt payment info
  'apiKey',         // ✓ Encrypt secrets
]
```

## Common TTL Values

- `60` = 1 minute
- `300` = 5 minutes  
- `1800` = 30 minutes
- `3600` = 1 hour
- `7200` = 2 hours
- `86400` = 1 day

## Security

- AES-256-CTR encryption
- Keys stored in secure storage (Keychain/Keystore)
- Auto-generated keys per app instance
- Selective encryption reduces attack surface
