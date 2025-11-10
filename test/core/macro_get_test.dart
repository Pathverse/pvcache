import 'package:flutter_test/flutter_test.dart';
import 'package:pvcache/pvcache.dart';
import 'package:pvcache/hooks/ttl.dart';

void main() {
  setUpAll(() {
    PVBridge.testMode = true;
  });

  late PVCache cache;

  // Mock API responses
  final mockUsers = {
    '1': {'id': '1', 'name': 'Alice', 'email': 'alice@example.com'},
    '2': {'id': '2', 'name': 'Bob', 'email': 'bob@example.com'},
    '123': {'id': '123', 'name': 'Charlie', 'email': 'charlie@example.com'},
  };

  final mockProducts = {
    'abc-123': {'id': 'abc-123', 'name': 'Widget', 'price': 29.99},
    'xyz-789': {'id': 'xyz-789', 'name': 'Gadget', 'price': 49.99},
  };

  final mockConfigs = {
    'theme': {'value': 'dark', 'updated': '2024-01-01'},
    'language': {'value': 'en', 'updated': '2024-01-01'},
  };

  // Mock fetch functions
  Future<dynamic> fetchUser(String key) async {
    final userId = key.split(':')[1];
    await Future.delayed(Duration(milliseconds: 10)); // Simulate API delay
    return mockUsers[userId];
  }

  Future<dynamic> fetchProduct(String key) async {
    final productId = key.split(':')[1];
    await Future.delayed(Duration(milliseconds: 10));
    return mockProducts[productId];
  }

  Future<dynamic> fetchConfig(String key) async {
    final configKey = key.substring(7); // Remove 'config:' prefix
    await Future.delayed(Duration(milliseconds: 10));
    return mockConfigs[configKey];
  }

  setUp(() async {
    // Create cache with macro get handlers
    cache = PVCache(
      env: 'test_macro_get',
      hooks: [],
      defaultMetadata: {},
      entryStorageType: StorageType.inMemory,
      metadataStorageType: StorageType.inMemory,
      macroGetHandlers: {
        // User pattern: user:123
        RegExp(r'^user:\d+$'): fetchUser,
        // Product pattern: product:abc-123
        RegExp(r'^product:[a-z0-9-]+$'): fetchProduct,
        // Config pattern: config:*
        'config:': fetchConfig,
      },
    );
  });

  tearDown(() async {
    await cache.clear();
  });

  group('Macro Get Hook - Basic Functionality', () {
    test('auto-fetches user on cache miss with regex pattern', () async {
      // First get should trigger fetch
      final user1 = await cache.get('user:1');
      expect(user1, isNotNull);
      expect(user1['name'], 'Alice');

      // Second get should return cached value (no fetch)
      final user1Cached = await cache.get('user:1');
      expect(user1Cached, isNotNull);
      expect(user1Cached['name'], 'Alice');
    });

    test('auto-fetches product on cache miss with regex pattern', () async {
      final product = await cache.get('product:abc-123');
      expect(product, isNotNull);
      expect(product['name'], 'Widget');
      expect(product['price'], 29.99);
    });

    test('auto-fetches config on cache miss with prefix pattern', () async {
      final config = await cache.get('config:theme');
      expect(config, isNotNull);
      expect(config['value'], 'dark');
    });

    test('returns null for non-matching patterns', () async {
      final result = await cache.get('unknown:pattern');
      expect(result, isNull);
    });

    test('returns null when fetch returns null', () async {
      // User 999 doesn't exist in mock data
      final user = await cache.get('user:999');
      expect(user, isNull);
    });

    test('multiple different patterns work independently', () async {
      final user = await cache.get('user:2');
      final product = await cache.get('product:xyz-789');
      final config = await cache.get('config:language');

      expect(user['name'], 'Bob');
      expect(product['name'], 'Gadget');
      expect(config['value'], 'en');
    });
  });

  group('Macro Get Hook - Caching Behavior', () {
    test('fetched data is cached and retrievable', () async {
      // First get triggers fetch
      final user1 = await cache.get('user:123');
      expect(user1, isNotNull);

      // Verify it's actually cached by checking exists
      final exists = await cache.exists('user:123');
      expect(exists, isTrue);

      // Get again - should be from cache
      final user2 = await cache.get('user:123');
      expect(user2, isNotNull);
      expect(user2['name'], 'Charlie');
    });

    test('manually cached data takes precedence over fetch', () async {
      // Manually put data
      await cache.put('user:1', {
        'id': '1',
        'name': 'Manual Alice',
        'email': 'manual@example.com',
      });

      // Get should return manual data, not fetch
      final user = await cache.get('user:1');
      expect(user['name'], 'Manual Alice');
    });

    test('deleted cache entries trigger re-fetch', () async {
      // First fetch
      await cache.get('user:1');

      // Delete
      await cache.delete('user:1');

      // Get again - should re-fetch
      final user = await cache.get('user:1');
      expect(user, isNotNull);
      expect(user['name'], 'Alice');
    });
  });

  group('Macro Get Hook - Pattern Matching', () {
    test('exact string match works', () async {
      final exactCache = PVCache(
        env: 'test_exact',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
        macroGetHandlers: {
          'exact:key': (key) async => {'matched': true},
        },
      );

      final result = await exactCache.get('exact:key');
      expect(result, isNotNull);
      expect(result['matched'], isTrue);

      await exactCache.clear();
    });

    test('prefix match works', () async {
      final result = await cache.get('config:anything');
      // Should match 'config:' prefix but return null (no such config)
      expect(result, isNull);
    });

    test('regex match is case-sensitive by default', () async {
      // Should match (lowercase)
      final user1 = await cache.get('user:123');
      expect(user1, isNotNull);

      // Won't match (uppercase)
      final user2 = await cache.get('USER:123');
      expect(user2, isNull);
    });

    test('complex regex patterns work', () async {
      final complexCache = PVCache(
        env: 'test_complex',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
        macroGetHandlers: {
          // Match: session:user_123:token
          RegExp(r'^session:[a-z]+_\d+:token$'): (key) async => {
            'token': 'abc123',
          },
        },
      );

      final match = await complexCache.get('session:user_123:token');
      expect(match, isNotNull);

      final noMatch = await complexCache.get('session:user:token');
      expect(noMatch, isNull);

      await complexCache.clear();
    });
  });

  group('Macro Get Hook - Error Handling', () {
    test('continues to next pattern on fetch error', () async {
      final errorCache = PVCache(
        env: 'test_error',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
        macroGetHandlers: {
          // First handler throws error
          'error:': (key) async => throw Exception('Fetch failed'),
          // Second handler succeeds
          'error:retry': (key) async => {'success': true},
        },
      );

      // Should try first handler, fail, then succeed with second
      final result = await errorCache.get('error:retry');
      expect(result, isNotNull);
      expect(result['success'], isTrue);

      await errorCache.clear();
    });

    test('returns null when all handlers fail', () async {
      final errorCache = PVCache(
        env: 'test_all_fail',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
        macroGetHandlers: {
          'fail:': (key) async => throw Exception('Always fails'),
        },
      );

      final result = await errorCache.get('fail:something');
      expect(result, isNull);

      await errorCache.clear();
    });
  });

  group('Macro Get Hook - With Other Hooks', () {
    test('works with TTL hook', () async {
      // Import TTL hook
      final ttlCache = PVCache(
        env: 'test_macro_ttl',
        hooks: [...createTTLHooks()],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
        macroGetHandlers: {'user:': fetchUser},
        macroGetDefaultMetadata: {'ttl': 1}, // 1 second TTL
      );

      // Fetch and cache with TTL
      final user1 = await ttlCache.get('user:1');
      expect(user1, isNotNull);

      // Should be cached
      final user2 = await ttlCache.get('user:1');
      expect(user2, isNotNull);

      // Wait for expiration
      await Future.delayed(Duration(seconds: 2));

      // Should re-fetch after TTL expires
      final user3 = await ttlCache.get('user:1');
      expect(user3, isNotNull);

      await ttlCache.clear();
    });
  });

  group('Macro Get Hook - With TTL Metadata', () {
    test('creates cache with default TTL metadata', () async {
      final ttlCache = PVCache(
        env: 'test_with_ttl',
        hooks: [...createTTLHooks()],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
        macroGetHandlers: {'user:': fetchUser},
        macroGetDefaultMetadata: {'ttl': 3600},
      );

      // Fetch - should be cached with TTL
      final user = await ttlCache.get('user:1');
      expect(user, isNotNull);

      // Verify it's cached
      final exists = await ttlCache.exists('user:1');
      expect(exists, isTrue);

      await ttlCache.clear();
    });
  });

  group('Macro Get Hook - Pattern Order', () {
    test('first matching handler wins', () async {
      int fetchCount = 0;

      final priorityCache = PVCache(
        env: 'test_priority',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
        macroGetHandlers: {
          'test:': (key) async {
            fetchCount++;
            return {'priority': 'first'};
          },
          'test:key': (key) async {
            fetchCount++;
            return {'priority': 'second'};
          },
        },
      );

      final result = await priorityCache.get('test:key');
      // First matching handler should win
      expect(result['priority'], 'first');
      expect(fetchCount, 1); // Only one fetch should occur

      await priorityCache.clear();
    });
  });

  group('Macro Get Hook - Caching Behavior', () {
    test('fetched data is cached by default', () async {
      final defaultCache = PVCache(
        env: 'test_default_cache',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
        macroGetHandlers: {'user:': fetchUser},
      );

      // First get - fetches and caches
      final user1 = await defaultCache.get('user:1');
      expect(user1, isNotNull);

      // Check if cached (should be cached)
      final exists = await defaultCache.exists('user:1');
      expect(exists, isTrue);

      await defaultCache.clear();
    });
  });
}
