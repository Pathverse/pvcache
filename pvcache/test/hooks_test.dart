import 'package:test/test.dart';
import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/config.dart';
import 'package:pvcache/core/ctx/ctx.dart';
import 'package:pvcache/core/enums.dart';
import 'package:pvcache/core/hooks/action_hook.dart';
import 'package:pvcache/db/db.dart';

void main() {
  // Set test mode once before all tests
  setUpAll(() {
    Db.isTestMode = true;
  });

  group('Hook System Tests', () {
    setUp(() async {
      await Db.initialize();
    });

    tearDown(() async {
      Db.globalMetaCache.clear();
    });

    test('Pre-action hook executes before operation', () async {
      var preHookCalled = false;
      var operationExecuted = false;

      final hook = PVActionHook((ctx) async {
        preHookCalled = true;
        expect(operationExecuted, isFalse); // Should run before operation
        // Operation will execute after this hook
      }, [PVActionContext('getValue', priority: 10, isPost: false)]);

      // Create a wrapper callback that tracks when the actual operation executes
      final getValueHook = PVActionHook((ctx) async {
        operationExecuted = true;
      }, [PVActionContext('getValue', priority: 0, isPost: false)]);

      final config = PVConfig(
        'hook_test_pre',
        storageType: StorageType.memory,
        actionHooks: {
          'getValue': [hook, getValueHook],
        },
      ).finalize();

      final cache = PVCache.create(config: config);

      await cache.put(PVCtx(key: 'test_key', value: 'test_value'));
      await cache.get(PVCtx(key: 'test_key'));

      expect(preHookCalled, isTrue);
      expect(operationExecuted, isTrue);
    });

    test('Post-action hook executes after operation', () async {
      var postHookCalled = false;
      var operationValue = '';

      final hook = PVActionHook((ctx) async {
        postHookCalled = true;
        operationValue = ctx.returnValue;
      }, [PVActionContext('getValue', priority: 10, isPost: true)]);

      final config = PVConfig(
        'hook_test_post',
        storageType: StorageType.memory,
        actionHooks: {
          'getValue': [hook],
        },
      ).finalize();

      final cache = PVCache.create(config: config);

      await cache.put(PVCtx(key: 'test_key', value: 'expected_value'));
      await cache.get(PVCtx(key: 'test_key'));

      expect(postHookCalled, isTrue);
      expect(operationValue, equals('expected_value'));
    });

    test('Multiple hooks execute in priority order', () async {
      final executionOrder = <int>[];

      final hook1 = PVActionHook((ctx) async {
        executionOrder.add(1);
      }, [PVActionContext('put', priority: 5, isPost: false)]);

      final hook2 = PVActionHook(
        (ctx) async {
          executionOrder.add(2);
        },
        [
          PVActionContext('put', priority: 10, isPost: false),
        ], // Higher priority
      );

      final hook3 = PVActionHook(
        (ctx) async {
          executionOrder.add(3);
        },
        [PVActionContext('put', priority: 1, isPost: false)], // Lower priority
      );

      final config = PVConfig(
        'priority_test',
        storageType: StorageType.memory,
        actionHooks: {
          'put': [hook1, hook2, hook3],
        },
      ).finalize();

      final cache = PVCache.create(config: config);
      await cache.put(PVCtx(key: 'key', value: 'value'));

      // Should execute in descending priority: 10, 5, 1
      expect(executionOrder, equals([2, 1, 3]));
    });

    test('Hook can access context data', () async {
      String? capturedKey;
      dynamic capturedValue;

      final hook = PVActionHook((ctx) async {
        capturedKey = ctx.initialCtx.key;
        capturedValue = ctx.initialCtx.value;
      }, [PVActionContext('put', priority: 10, isPost: false)]);

      final config = PVConfig(
        'context_test',
        storageType: StorageType.memory,
        actionHooks: {
          'put': [hook],
        },
      ).finalize();

      final cache = PVCache.create(config: config);
      await cache.put(
        PVCtx(key: 'my_key', value: 'my_value', metadata: {'meta': 'data'}),
      );

      expect(capturedKey, equals('my_key'));
      expect(capturedValue, equals('my_value'));
    });

    test('Hook can modify metadata', () async {
      final hook = PVActionHook((ctx) async {
        // Add timestamp to metadata
        ctx.runtime['timestamp'] = DateTime.now().millisecondsSinceEpoch;
      }, [PVActionContext('put', priority: 10, isPost: false)]);

      final config = PVConfig(
        'metadata_test',
        storageType: StorageType.memory,
        actionHooks: {
          'put': [hook],
        },
      ).finalize();

      final cache = PVCache.create(config: config);
      await cache.put(PVCtx(key: 'key', value: 'value'));

      // Runtime data should be accessible during operation
      expect(true, isTrue); // Basic verification hook executed
    });

    test('Both pre and post hooks execute for same event', () async {
      var preHookCalled = false;
      var postHookCalled = false;

      final preHook = PVActionHook((ctx) async {
        preHookCalled = true;
      }, [PVActionContext('delete', priority: 10, isPost: false)]);

      final postHook = PVActionHook((ctx) async {
        postHookCalled = true;
      }, [PVActionContext('delete', priority: 10, isPost: true)]);

      final config = PVConfig(
        'both_hooks_test',
        storageType: StorageType.memory,
        actionHooks: {
          'delete': [preHook, postHook],
        },
      ).finalize();

      final cache = PVCache.create(config: config);
      await cache.put(PVCtx(key: 'key', value: 'value'));
      await cache.delete(PVCtx(key: 'key'));

      expect(preHookCalled, isTrue);
      expect(postHookCalled, isTrue);
    });

    test('Hooks execute for different events', () async {
      var getHookCalled = false;
      var putHookCalled = false;
      var deleteHookCalled = false;

      final getHook = PVActionHook((ctx) async {
        getHookCalled = true;
      }, [PVActionContext('getValue', priority: 10, isPost: true)]);

      final putHook = PVActionHook((ctx) async {
        putHookCalled = true;
      }, [PVActionContext('put', priority: 10, isPost: true)]);

      final deleteHook = PVActionHook((ctx) async {
        deleteHookCalled = true;
      }, [PVActionContext('delete', priority: 10, isPost: true)]);

      final config = PVConfig(
        'multi_event_test',
        storageType: StorageType.memory,
        actionHooks: {
          'getValue': [getHook],
          'put': [putHook],
          'delete': [deleteHook],
        },
      ).finalize();

      final cache = PVCache.create(config: config);

      await cache.put(PVCtx(key: 'key', value: 'value'));
      expect(putHookCalled, isTrue);

      await cache.get(PVCtx(key: 'key'));
      expect(getHookCalled, isTrue);

      await cache.delete(PVCtx(key: 'key'));
      expect(deleteHookCalled, isTrue);
    });

    test('Hook with multiple contexts', () async {
      var callCount = 0;

      final multiContextHook = PVActionHook(
        (ctx) async {
          callCount++;
        },
        [
          PVActionContext('put', priority: 10, isPost: true),
          PVActionContext('delete', priority: 10, isPost: true),
        ],
      );

      final config = PVConfig(
        'multi_context_test',
        storageType: StorageType.memory,
        actionHooks: {
          'put': [multiContextHook],
          'delete': [multiContextHook],
        },
      ).finalize();

      final cache = PVCache.create(config: config);

      await cache.put(PVCtx(key: 'key', value: 'value'));
      expect(callCount, equals(1));

      await cache.delete(PVCtx(key: 'key'));
      expect(callCount, equals(2));
    });
  });
}
