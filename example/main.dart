import 'package:flutter/material.dart';
import 'cache_manager.dart';
import 'models/user.dart';
import 'services/user_service.dart';

/// Main example demonstrating TTL (Time-To-Live) caching and Encryption
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('\n=== PVCache TTL + Encryption Example ===\n');

  // Initialize cache manager
  final cacheManager = CacheManager();
  final userService = UserService(cacheManager);

  // Example 1: Cache a single user for 5 minutes
  print('--- Example 1: Single User Cache (5 min TTL) ---');
  final user1 = User(id: '1', name: 'Alice', email: 'alice@example.com');
  await userService.cacheUser(user1);

  var cachedUser = await userService.getCachedUser('1');
  print('Retrieved: $cachedUser\n');

  // Example 2: Cache user list for 1 minute
  print('--- Example 2: User List Cache (1 min TTL) ---');
  final users = [
    User(id: '1', name: 'Alice', email: 'alice@example.com'),
    User(id: '2', name: 'Bob', email: 'bob@example.com'),
    User(id: '3', name: 'Charlie', email: 'charlie@example.com'),
  ];
  await userService.cacheUserList(users);

  var cachedList = await userService.getCachedUserList();
  print('Retrieved ${cachedList?.length} users\n');

  // Example 3: Cache session token for 1 hour
  print('--- Example 3: Session Cache (1 hour TTL) ---');
  await userService.cacheSession('abc123token');

  var session = await userService.getCachedSession();
  print('Session token: $session\n');

  // Example 4: Short TTL demonstration (3 seconds)
  print('--- Example 4: Short TTL Demo (3 seconds) ---');
  await cacheManager.set('temp_data', 'This expires soon!', ttlSeconds: 3);
  print('✓ Cached temp data for 3 seconds');

  print('Checking immediately...');
  var tempData = await cacheManager.get('temp_data');
  print('Result: $tempData');

  print('Waiting 4 seconds...');
  await Future.delayed(Duration(seconds: 4));

  print('Checking after expiration...');
  tempData = await cacheManager.get('temp_data');
  print('Result: $tempData (should be null)\n');

  // Example 5: Cache without TTL (no expiration)
  print('--- Example 5: Permanent Cache (no TTL) ---');
  await cacheManager.set('permanent', 'This never expires');
  print('✓ Cached permanent data without TTL');

  var permanentData = await cacheManager.get('permanent');
  print('Retrieved: $permanentData\n');

  // Example 6: Different TTLs for different data types
  print('--- Example 6: Multiple TTLs ---');
  await cacheManager.set('config', {
    'theme': 'dark',
  }, ttlSeconds: 3600); // 1 hour
  print('✓ Config cached for 1 hour');

  await cacheManager.set('api_response', {
    'data': [1, 2, 3],
  }, ttlSeconds: 60); // 1 min
  print('✓ API response cached for 1 minute');

  await cacheManager.set(
    'hot_data',
    'Changes frequently',
    ttlSeconds: 10,
  ); // 10 sec
  print('✓ Hot data cached for 10 seconds\n');

  // ===== ENCRYPTION EXAMPLES =====

  // Example 7: Secure User Cache with Encryption
  print('--- Example 7: Encrypted User Cache (auto-generated key) ---');
  final secureUser = User(
    id: '100',
    name: 'Secure Alice',
    email: 'secure@example.com',
  );
  await userService.cacheSecureUser(secureUser);

  var retrievedSecureUser = await userService.getCachedSecureUser('100');
  print('Retrieved encrypted user: $retrievedSecureUser');
  print('Note: Data is encrypted in storage, decrypted on retrieval\n');

  // Example 8: Encrypted Authentication Token
  print('--- Example 8: Encrypted Auth Token (2 hour TTL) ---');
  await userService.cacheAuthToken('super_secret_jwt_token_12345');

  var authToken = await userService.getCachedAuthToken();
  print('Auth token: ${authToken?.substring(0, 20)}...');
  print('Note: Sensitive tokens are encrypted at rest\n');

  // Example 9: Encrypted Credentials
  print('--- Example 9: Encrypted Credentials (30 min TTL) ---');
  await userService.cacheCredentials('user_123', {
    'email': 'user@example.com',
    'password_hash': 'hashed_password_value',
    'salt': 'random_salt_value',
  });

  var credentials = await userService.getCachedCredentials('user_123');
  print('Retrieved credentials: ${credentials?.keys.join(", ")}');
  print('Note: All values encrypted for security\n');

  // Example 10: Direct encrypted cache usage
  print('--- Example 10: Direct Secure Cache (with TTL) ---');
  await cacheManager.setSecure(
    'api_key',
    {
      'key': 'sk_live_abc123xyz789',
      'created': DateTime.now().toIso8601String(),
    },
    ttlSeconds: 3600, // 1 hour
  );
  print('✓ API key cached with encryption for 1 hour');

  var apiKeyData = await cacheManager.getSecure('api_key');
  print('Retrieved API key: ${apiKeyData?['key'].substring(0, 15)}...');
  print('Note: Automatic encryption with auto-generated key\n');

  // Example 11: Compare encrypted vs unencrypted
  print('--- Example 11: Encryption Comparison ---');
  await cacheManager.set('plain_data', 'This is stored as plain text');
  await cacheManager.setSecure(
    'encrypted_data',
    'This is encrypted in storage',
  );
  print('✓ Stored same data in both caches');
  print('Plain data: Readable in database');
  print('Encrypted data: Base64 ciphertext in database\n');

  // ===== SELECTIVE ENCRYPTION EXAMPLES =====

  // Example 12: Selective Field Encryption - User Data
  print('--- Example 12: Selective Encryption - User Data ---');
  final userData = {
    'id': 123,
    'name': 'John Doe',
    'email': 'john@example.com',
    'password': 'secret_password_123',
    'profile': {
      'bio': 'Software developer',
      'ssn': '123-45-6789',
      'phone': '555-1234',
    },
  };

  await cacheManager.setSelective(
    'user:123',
    userData,
    secureFields: ['password', 'profile.ssn'],
    ttlSeconds: 300,
  );
  print('✓ Cached user with selective encryption');
  print('  Encrypted fields: password, profile.ssn');
  print('  Readable fields: id, name, email, profile.bio, profile.phone');

  var retrievedUser = await cacheManager.getSelective('user:123');
  print('Retrieved user: ${retrievedUser?['name']}');
  print('Password (decrypted): ${retrievedUser?['password']}');
  print('SSN (decrypted): ${retrievedUser?['profile']['ssn']}');
  print('Note: Only sensitive fields are encrypted, rest remain readable\n');

  // Example 13: Selective Encryption - API Configuration
  print('--- Example 13: Selective Encryption - API Config ---');
  final apiConfig = {
    'service': 'stripe',
    'version': 'v3',
    'apiKey': 'sk_live_abc123xyz789',
    'apiSecret': 'secret_key_xyz789abc123',
    'webhookUrl': 'https://example.com/webhook',
    'webhookSecret': 'whsec_abc123xyz',
  };

  await cacheManager.setSelective(
    'config:stripe',
    apiConfig,
    secureFields: ['apiKey', 'apiSecret', 'webhookSecret'],
    ttlSeconds: 3600,
  );
  print('✓ Cached API config with selective encryption');
  print('  Encrypted: apiKey, apiSecret, webhookSecret');
  print('  Readable: service, version, webhookUrl');

  var retrievedConfig = await cacheManager.getSelective('config:stripe');
  print('Service: ${retrievedConfig?['service']}');
  print(
    'API Key (decrypted): ${retrievedConfig?['apiKey'].substring(0, 15)}...',
  );
  print('Note: Config metadata readable, secrets encrypted\n');

  // Example 14: Selective Encryption - Session with Tokens
  print('--- Example 14: Selective Encryption - Session Tokens ---');
  final sessionData = {
    'userId': 'user_123',
    'username': 'johndoe',
    'loginTime': DateTime.now().toIso8601String(),
    'tokens': {
      'access': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
      'refresh': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ8...',
    },
    'mfaCode': '123456',
  };

  await cacheManager.setSelective(
    'session:user_123',
    sessionData,
    secureFields: ['tokens.access', 'tokens.refresh', 'mfaCode'],
    ttlSeconds: 7200, // 2 hours
  );
  print('✓ Cached session with selective encryption');
  print('  Encrypted: tokens.access, tokens.refresh, mfaCode');
  print('  Readable: userId, username, loginTime');

  var retrievedSession = await cacheManager.getSelective('session:user_123');
  print('Username: ${retrievedSession?['username']}');
  print(
    'Access token (decrypted): ${retrievedSession?['tokens']['access'].substring(0, 20)}...',
  );
  print('Note: User info readable, sensitive tokens encrypted\n');

  // Example 15: Selective Encryption - Payment Data
  print('--- Example 15: Selective Encryption - Payment Info ---');
  final paymentData = {
    'paymentId': 'pay_123',
    'amount': 99.99,
    'currency': 'USD',
    'cardNumber': '4242424242424242',
    'cardHolder': 'John Doe',
    'cvv': '123',
    'expiryMonth': 12,
    'expiryYear': 2025,
  };

  await cacheManager.setSelective(
    'payment:pay_123',
    paymentData,
    secureFields: ['cardNumber', 'cvv'],
    ttlSeconds: 600, // 10 minutes
  );
  print('✓ Cached payment with selective encryption');
  print('  Encrypted: cardNumber, cvv');
  print('  Readable: paymentId, amount, currency, cardHolder, expiry');

  var retrievedPayment = await cacheManager.getSelective('payment:pay_123');
  print('Payment ID: ${retrievedPayment?['paymentId']}');
  print('Amount: \$${retrievedPayment?['amount']}');
  print('Card (decrypted): ${retrievedPayment?['cardNumber']}');
  print('Note: PII encrypted, transaction metadata readable\n');

  // Example 16: Comparison of all three cache types
  print('--- Example 16: Cache Type Comparison ---');
  final testData = {
    'field1': 'value1',
    'field2': 'value2',
    'secret': 'sensitive_data',
  };

  await cacheManager.set('compare:regular', testData);
  await cacheManager.setSecure('compare:secure', testData);
  await cacheManager.setSelective(
    'compare:selective',
    testData,
    secureFields: ['secret'],
  );

  print('✓ Same data stored in all three cache types:');
  print('  Regular: All fields readable in database');
  print('  Secure: Entire object encrypted in database');
  print('  Selective: Only "secret" field encrypted\n');

  print('Best practices:');
  print('- Use Regular cache for non-sensitive data');
  print('- Use Secure cache when entire object is sensitive');
  print('- Use Selective cache for mixed sensitivity data\n');

  // Cleanup
  print('--- Cleanup ---');
  await cacheManager.close();
  print('✓ Cache closed\n');

  print('=== Example Complete ===');
  print('Key takeaways:');
  print('- TTL hooks provide automatic expiration');
  print('- Encryption hooks use auto-generated keys (stored securely)');
  print(
    '- Encryption is transparent - data encrypted on write, decrypted on read',
  );
  print('- Both hooks can be combined for secure + expiring cache');
  print('- Selective encryption balances security with readability\n');
}
