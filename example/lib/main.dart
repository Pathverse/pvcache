import 'package:flutter/material.dart';
import 'package:pvcache/pvcache.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create encryption plugins for each strategy
  final passivePlugin = await createEncryptedHook(
    rotationStrategy: KeyRotationStrategy.passive,
    secureStorageKey: 'passive_key',
  );

  final activePlugin = await createEncryptedHook(
    rotationStrategy: KeyRotationStrategy.active,
    secureStorageKey: 'active_key',
  );

  final reactivePlugin = await createEncryptedHook(
    rotationStrategy: KeyRotationStrategy.reactive,
    secureStorageKey: 'reactive_key',
    rotationCallback: (error, key) async {
      debugPrint('Decryption failed for key: $key');
      debugPrint('Error: $error');
      return true;
    },
  );

  // Register configurations
  PVCache.registerConfig(env: 'passive_demo', plugins: [passivePlugin]);
  PVCache.registerConfig(env: 'active_demo', plugins: [activePlugin]);
  PVCache.registerConfig(env: 'reactive_demo', plugins: [reactivePlugin]);

  // Initialize HiveHook
  await HHiveCore.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PVCache Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  String _output = 'Ready to test encryption strategies';
  final _storage = const FlutterSecureStorage();

  void _log(String message) {
    setState(() {
      _output += '\n$message';
    });
    debugPrint(message);
  }

  Future<void> _testPassiveMode() async {
    _log('\n=== Testing Passive Mode ===');

    final cache = PVCache.getCache('passive_demo');

    // Store encrypted data
    await cache.put('test_key', 'secret_data_123');
    _log('✓ Stored encrypted data');

    // Read back (should work with correct key)
    final result = await cache.get('test_key');
    _log('✓ Read data: $result');

    // Check key health
    final keyExists = await _storage.read(key: 'passive_key');
    _log('Key health: ${keyExists != null ? "✓ Key exists" : "✗ No key"}');
  }

  Future<void> _corruptPassiveKey() async {
    _log('\n=== Corrupting Passive Key ===');

    // Corrupt the key by writing garbage
    await _storage.write(key: 'passive_key', value: 'corrupted_key_data');
    _log('✓ Key corrupted');

    // Try to read
    try {
      final cache = PVCache.getCache('passive_demo');
      final result = await cache.get('test_key');
      _log('Read result: $result');
    } catch (e) {
      _log(
        '✗ Decryption failed (expected): ${e.toString().substring(0, 50)}...',
      );
    }

    _log('Passive mode: Requires manual key rotation');
  }

  Future<void> _testActiveMode() async {
    _log('\n=== Testing Active Mode ===');

    final cache = PVCache.getCache('active_demo');

    // Store encrypted data
    await cache.put('test_key', 'secret_data_456');
    _log('✓ Stored encrypted data');

    // Read back (should work)
    final result = await cache.get('test_key');
    _log('✓ Read data: $result');

    // Check key health
    final keyExists = await _storage.read(key: 'active_key');
    _log('Key health: ${keyExists != null ? "✓ Key exists" : "✗ No key"}');
  }

  Future<void> _corruptActiveKey() async {
    _log('\n=== Corrupting Active Key ===');

    // Corrupt the key
    await _storage.write(key: 'active_key', value: 'corrupted_key_data');
    _log('✓ Key corrupted');

    // Try to read (should auto-rotate)
    final cache = PVCache.getCache('active_demo');
    final result = await cache.get('test_key');
    _log('Read result: $result');

    // Check if key was rotated
    final newKey = await _storage.read(key: 'active_key');
    _log(
      newKey != 'corrupted_key_data'
          ? '✓ Key auto-rotated (active mode)'
          : '✗ Key not rotated',
    );
  }

  Future<void> _testReactiveMode() async {
    _log('\n=== Testing Reactive Mode ===');

    final cache = PVCache.getCache('reactive_demo');

    // Store encrypted data
    await cache.put('test_key', 'secret_data_789');
    _log('✓ Stored encrypted data');

    // Read back (should work)
    final result = await cache.get('test_key');
    _log('✓ Read data: $result');

    // Check key health
    final keyExists = await _storage.read(key: 'reactive_key');
    _log('Key health: ${keyExists != null ? "✓ Key exists" : "✗ No key"}');
  }

  Future<void> _corruptReactiveKey() async {
    _log('\n=== Corrupting Reactive Key ===');

    // Corrupt the key
    await _storage.write(key: 'reactive_key', value: 'corrupted_key_data');
    _log('✓ Key corrupted');

    // Try to read (callback will decide)
    _log('Watch console for callback output...');
    final cache = PVCache.getCache('reactive_demo');
    final result = await cache.get('test_key');
    _log('Read result: $result');

    // Check if key was rotated (callback returns true)
    final newKey = await _storage.read(key: 'reactive_key');
    _log(
      newKey != 'corrupted_key_data'
          ? '✓ Key rotated (callback returned true)'
          : '✗ Key not rotated',
    );
  }

  Future<void> _checkAllKeyHealth() async {
    _log('\n=== Checking All Key Health ===');

    final passiveKey = await _storage.read(key: 'passive_key');
    final activeKey = await _storage.read(key: 'active_key');
    final reactiveKey = await _storage.read(key: 'reactive_key');

    _log(
      'Passive key: ${passiveKey != null ? "✓ Exists (${passiveKey.substring(0, 16)}...)" : "✗ Missing"}',
    );
    _log(
      'Active key: ${activeKey != null ? "✓ Exists (${activeKey.substring(0, 16)}...)" : "✗ Missing"}',
    );
    _log(
      'Reactive key: ${reactiveKey != null ? "✓ Exists (${reactiveKey.substring(0, 16)}...)" : "✗ Missing"}',
    );
  }

  void _clearOutput() {
    setState(() {
      _output = 'Ready to test encryption strategies';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('PVCache Encryption Demo'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _testPassiveMode,
                        child: const Text('Test Passive'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _corruptPassiveKey,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text('Corrupt Key'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _testActiveMode,
                        child: const Text('Test Active'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _corruptActiveKey,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text('Corrupt Key'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _testReactiveMode,
                        child: const Text('Test Reactive'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _corruptReactiveKey,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text('Corrupt Key'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(),
                ElevatedButton.icon(
                  onPressed: _checkAllKeyHealth,
                  icon: const Icon(Icons.health_and_safety),
                  label: const Text('Check All Key Health'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _clearOutput,
                  child: const Text('Clear Output'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _output,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
