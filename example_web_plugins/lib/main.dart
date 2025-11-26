import 'package:flutter/material.dart';
import 'package:pvcache/pvcache.dart';
import 'package:pvcache/helper/error_resolve.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress IndexedDB interop errors from Sembast on web
  suppressSembastWebErrors();

  // Initialize database
  await Db.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PVCache Web Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const CacheDemoPage(),
    );
  }
}

class CacheDemoPage extends StatefulWidget {
  const CacheDemoPage({super.key});

  @override
  State<CacheDemoPage> createState() => _CacheDemoPageState();
}

class _CacheDemoPageState extends State<CacheDemoPage> {
  late PVCache ttlCache;
  late PVCache lruCache;
  late PVCache combinedCache;

  final List<String> _logs = [];
  String? _lastResult;

  @override
  void initState() {
    super.initState();
    _initializeCaches();
  }

  void _initializeCaches() {
    // TTL Cache: 5 second expiration
    final ttlConfig = PVConfig(
      'ttl_demo',
      storageType: StorageType.separateFilePreferred,
      plugins: [TTLPlugin(defaultTTLMillis: 5000)],
    ).finalize();
    ttlCache = PVCache.create(config: ttlConfig);

    // LRU Cache: Max 5 items
    final lruConfig = PVConfig(
      'lru_demo',
      storageType: StorageType.separateFilePreferred,
      plugins: [LRUPlugin(maxSize: 5)],
    ).finalize();
    lruCache = PVCache.create(config: lruConfig);

    // Combined LRU + TTL: Max 3 items, 10 second TTL
    final combinedConfig = PVConfig(
      'combined_demo',
      storageType: StorageType.separateFilePreferred,
      plugins: [LRUTTLPlugin(maxSize: 3, defaultTTLMillis: 10000)],
    ).finalize();
    combinedCache = PVCache.create(config: combinedConfig);

    _log('✓ Caches initialized (IndexedDB storage)');
  }

  void _log(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
      if (_logs.length > 20) _logs.removeAt(0);
    });
  }

  // TTL Cache Operations
  Future<void> _ttlPut() async {
    await ttlCache.put(
      PVCtx(
        key: 'user_${DateTime.now().millisecond}',
        value: 'User Data ${DateTime.now().second}',
      ),
    );
    _log('TTL: Put item (expires in 5s)');
  }

  Future<void> _ttlGet() async {
    final keys = await ttlCache.iterateKey(PVCtx());
    if (keys.isEmpty) {
      _log('TTL: No items in cache');
      setState(() => _lastResult = 'Empty cache');
      return;
    }

    final key = keys.first;
    final value = await ttlCache.get(PVCtx(key: key));
    _log('TTL: Get "$key" = ${value ?? "EXPIRED"}');
    setState(() => _lastResult = value?.toString() ?? 'EXPIRED');
  }

  Future<void> _ttlContains() async {
    final keys = await ttlCache.iterateKey(PVCtx());
    if (keys.isEmpty) {
      _log('TTL: No keys to check');
      return;
    }

    final key = keys.first;
    final exists = await ttlCache.containsKey(PVCtx(key: key));
    _log('TTL: containsKey("$key") = $exists');
  }

  Future<void> _ttlDelete() async {
    final keys = await ttlCache.iterateKey(PVCtx());
    if (keys.isEmpty) {
      _log('TTL: No items to delete');
      return;
    }

    final key = keys.first;
    await ttlCache.delete(PVCtx(key: key));
    _log('TTL: Deleted "$key"');
  }

  Future<void> _ttlIterate() async {
    final entries = await ttlCache.iterateEntry(PVCtx());
    _log('TTL: Iterate - ${entries.length} items');
    setState(
      () => _lastResult = entries.map((e) => '${e.key}: ${e.value}').join(', '),
    );
  }

  Future<void> _ttlClear() async {
    await ttlCache.clear(PVCtx());
    _log('TTL: Cleared all items');
  }

  // LRU Cache Operations
  Future<void> _lruPut() async {
    final key = 'item_${DateTime.now().millisecond}';
    await lruCache.put(PVCtx(key: key, value: 'Data ${DateTime.now().second}'));
    _log('LRU: Put "$key" (max 5 items)');
  }

  Future<void> _lruGet() async {
    final keys = await lruCache.iterateKey(PVCtx());
    if (keys.isEmpty) {
      _log('LRU: No items in cache');
      setState(() => _lastResult = 'Empty cache');
      return;
    }

    final key = keys.first;
    final value = await lruCache.get(PVCtx(key: key));
    _log('LRU: Get "$key" = $value (moved to MRU)');
    setState(() => _lastResult = value?.toString() ?? 'null');
  }

  Future<void> _lruIterate() async {
    final entries = await lruCache.iterateEntry(PVCtx());
    _log('LRU: Iterate - ${entries.length} items');
    setState(
      () => _lastResult = entries.map((e) => '${e.key}: ${e.value}').join(', '),
    );
  }

  Future<void> _lruClear() async {
    await lruCache.clear(PVCtx());
    _log('LRU: Cleared all items');
  }

  // Combined Cache Operations
  Future<void> _combinedPut() async {
    final key = 'combo_${DateTime.now().millisecond}';
    await combinedCache.put(
      PVCtx(
        key: key,
        value: 'Data ${DateTime.now().second}',
        metadata: {'ttl': 8000}, // Custom TTL
      ),
    );
    _log('Combined: Put "$key" (max 3, 8s TTL)');
  }

  Future<void> _combinedGet() async {
    final keys = await combinedCache.iterateKey(PVCtx());
    if (keys.isEmpty) {
      _log('Combined: No items in cache');
      setState(() => _lastResult = 'Empty cache');
      return;
    }

    final key = keys.first;
    final value = await combinedCache.get(PVCtx(key: key));
    _log('Combined: Get "$key" = ${value ?? "EXPIRED"}');
    setState(() => _lastResult = value?.toString() ?? 'EXPIRED');
  }

  Future<void> _combinedIterate() async {
    final entries = await combinedCache.iterateEntry(PVCtx());
    _log('Combined: Iterate - ${entries.length} items');
    setState(
      () => _lastResult = entries.map((e) => '${e.key}: ${e.value}').join(', '),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PVCache Web Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Row(
        children: [
          // Left panel - Controls
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCacheSection(
                      'TTL Cache (5s expiration)',
                      Colors.orange,
                      [
                        _buildButton('Put', _ttlPut, Icons.add),
                        _buildButton('Get', _ttlGet, Icons.search),
                        _buildButton(
                          'Contains',
                          _ttlContains,
                          Icons.check_circle,
                        ),
                        _buildButton('Delete', _ttlDelete, Icons.delete),
                        _buildButton('Iterate', _ttlIterate, Icons.list),
                        _buildButton('Clear', _ttlClear, Icons.clear_all),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildCacheSection('LRU Cache (max 5 items)', Colors.blue, [
                      _buildButton('Put', _lruPut, Icons.add),
                      _buildButton('Get', _lruGet, Icons.search),
                      _buildButton('Iterate', _lruIterate, Icons.list),
                      _buildButton('Clear', _lruClear, Icons.clear_all),
                    ]),
                    const SizedBox(height: 24),
                    _buildCacheSection(
                      'Combined LRU+TTL (max 3, 10s TTL)',
                      Colors.green,
                      [
                        _buildButton('Put', _combinedPut, Icons.add),
                        _buildButton('Get', _combinedGet, Icons.search),
                        _buildButton('Iterate', _combinedIterate, Icons.list),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Right panel - Logs and Results
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_lastResult != null) ...[
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Last Result:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(_lastResult!),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Activity Log:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Card(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: ListView.builder(
                          reverse: true,
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                _logs[_logs.length - 1 - index],
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheSection(String title, Color color, List<Widget> buttons) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 4, height: 24, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: buttons),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String label, VoidCallback onPressed, IconData icon) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
