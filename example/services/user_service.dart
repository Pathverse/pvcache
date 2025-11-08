// ignore_for_file: avoid_print

import '../cache_manager.dart';
import '../models/user.dart';

/// Service that manages user data with TTL caching
class UserService {
  final CacheManager _cache;

  UserService(this._cache);

  /// Cache user data for 5 minutes
  Future<void> cacheUser(User user) async {
    const fiveMinutes = 5 * 60; // 300 seconds
    await _cache.set('user:${user.id}', user.toJson(), ttlSeconds: fiveMinutes);
    print('✓ Cached user ${user.name} for 5 minutes');
  }

  /// Cache user list for 1 minute (frequently changing data)
  Future<void> cacheUserList(List<User> users) async {
    const oneMinute = 60;
    final userList = users.map((u) => u.toJson()).toList();
    await _cache.set('users:list', userList, ttlSeconds: oneMinute);
    print('✓ Cached ${users.length} users for 1 minute');
  }

  /// Get cached user (returns null if expired)
  Future<User?> getCachedUser(String userId) async {
    final data = await _cache.get('user:$userId');
    if (data == null) {
      print('✗ User $userId not in cache or expired');
      return null;
    }
    print('✓ Retrieved user from cache');
    return User.fromJson(data as Map<String, dynamic>);
  }

  /// Get cached user list
  Future<List<User>?> getCachedUserList() async {
    final data = await _cache.get('users:list');
    if (data == null) {
      print('✗ User list not in cache or expired');
      return null;
    }
    final list = data as List;
    print('✓ Retrieved ${list.length} users from cache');
    return list.map((u) => User.fromJson(u as Map<String, dynamic>)).toList();
  }

  /// Cache session token for 1 hour
  Future<void> cacheSession(String token) async {
    const oneHour = 60 * 60;
    await _cache.set('session:token', token, ttlSeconds: oneHour);
    print('✓ Cached session token for 1 hour');
  }

  /// Get cached session
  Future<String?> getCachedSession() async {
    final token = await _cache.get('session:token');
    if (token == null) {
      print('✗ Session expired or not found');
      return null;
    }
    print('✓ Session still valid');
    return token as String;
  }

  // ===== Secure Methods (with encryption) =====

  /// Cache sensitive user data with encryption (e.g., auth tokens, personal info)
  Future<void> cacheSecureUser(User user) async {
    const fiveMinutes = 5 * 60; // 300 seconds
    await _cache.setSecure(
      'secure:user:${user.id}',
      user.toJson(),
      ttlSeconds: fiveMinutes,
    );
    print('✓ Securely cached user ${user.name} (encrypted) for 5 minutes');
  }

  /// Get encrypted user data (automatically decrypted)
  Future<User?> getCachedSecureUser(String userId) async {
    final data = await _cache.getSecure('secure:user:$userId');
    if (data == null) {
      print('✗ Secure user $userId not in cache or expired');
      return null;
    }
    print('✓ Retrieved encrypted user from cache (decrypted)');
    return User.fromJson(data as Map<String, dynamic>);
  }

  /// Cache authentication token with encryption for 2 hours
  Future<void> cacheAuthToken(String token) async {
    const twoHours = 2 * 60 * 60;
    await _cache.setSecure('auth:token', token, ttlSeconds: twoHours);
    print('✓ Securely cached auth token (encrypted) for 2 hours');
  }

  /// Get encrypted auth token
  Future<String?> getCachedAuthToken() async {
    final token = await _cache.getSecure('auth:token');
    if (token == null) {
      print('✗ Auth token expired or not found');
      return null;
    }
    print('✓ Auth token still valid (decrypted)');
    return token as String;
  }

  /// Cache sensitive user credentials (email/password hash) with encryption
  Future<void> cacheCredentials(
    String userId,
    Map<String, String> credentials,
  ) async {
    const thirtyMinutes = 30 * 60;
    await _cache.setSecure(
      'credentials:$userId',
      credentials,
      ttlSeconds: thirtyMinutes,
    );
    print('✓ Securely cached credentials (encrypted) for 30 minutes');
  }

  /// Get encrypted credentials
  Future<Map<String, String>?> getCachedCredentials(String userId) async {
    final data = await _cache.getSecure('credentials:$userId');
    if (data == null) {
      print('✗ Credentials expired or not found');
      return null;
    }
    print('✓ Retrieved credentials (decrypted)');
    return Map<String, String>.from(data as Map);
  }
}
