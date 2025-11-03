/// Utilities for working with nested data structures using dot notation paths
///
/// Example paths:
/// - "user.name" -> data['user']['name']
/// - "settings.theme.color" -> data['settings']['theme']['color']
/// - "items.0.title" -> data['items'][0]['title']
library;

/// Get a value from a nested structure using dot notation path
///
/// Example:
/// ```dart
/// final data = {'user': {'name': 'John', 'age': 30}};
/// final name = getNestedValue(data, 'user.name'); // 'John'
/// final age = getNestedValue(data, 'user.age'); // 30
/// final missing = getNestedValue(data, 'user.email'); // null
/// ```
dynamic getNestedValue(dynamic data, String path) {
  if (data == null) return null;

  final keys = path.split('.');
  dynamic current = data;

  for (final key in keys) {
    if (current == null) return null;

    // Handle list index access
    if (current is List) {
      final index = int.tryParse(key);
      if (index == null || index < 0 || index >= current.length) {
        return null;
      }
      current = current[index];
    }
    // Handle map key access
    else if (current is Map) {
      current = current[key];
    }
    // Can't navigate further
    else {
      return null;
    }
  }

  return current;
}

/// Set a value in a nested structure using dot notation path
///
/// Creates intermediate maps/lists as needed.
/// Returns true if successful, false if path is invalid.
///
/// Example:
/// ```dart
/// final data = <String, dynamic>{};
/// setNestedValue(data, 'user.name', 'John'); // data = {'user': {'name': 'John'}}
/// setNestedValue(data, 'user.age', 30); // data = {'user': {'name': 'John', 'age': 30}}
/// ```
bool setNestedValue(dynamic data, String path, dynamic value) {
  if (data == null) return false;
  if (!(data is Map || data is List)) return false;

  final keys = path.split('.');
  if (keys.isEmpty) return false;

  dynamic current = data;

  // Navigate to parent of target
  for (int i = 0; i < keys.length - 1; i++) {
    final key = keys[i];
    final nextKey = keys[i + 1];

    // Handle list index access
    if (current is List) {
      final index = int.tryParse(key);
      if (index == null || index < 0 || index >= current.length) {
        return false;
      }

      // Create intermediate structure if needed
      if (current[index] == null) {
        final isNextKeyNumeric = int.tryParse(nextKey) != null;
        current[index] = isNextKeyNumeric ? [] : <String, dynamic>{};
      }

      current = current[index];
    }
    // Handle map key access
    else if (current is Map) {
      // Create intermediate structure if needed
      if (!current.containsKey(key) || current[key] == null) {
        final isNextKeyNumeric = int.tryParse(nextKey) != null;
        current[key] = isNextKeyNumeric ? [] : <String, dynamic>{};
      }

      current = current[key];
    }
    // Can't navigate further
    else {
      return false;
    }
  }

  // Set the final value
  final lastKey = keys.last;

  if (current is List) {
    final index = int.tryParse(lastKey);
    if (index == null || index < 0 || index >= current.length) {
      return false;
    }
    current[index] = value;
    return true;
  } else if (current is Map) {
    current[lastKey] = value;
    return true;
  }

  return false;
}

/// Check if a nested path exists in the data structure
///
/// Example:
/// ```dart
/// final data = {'user': {'name': 'John'}};
/// hasNestedPath(data, 'user.name'); // true
/// hasNestedPath(data, 'user.age'); // false
/// ```
bool hasNestedPath(dynamic data, String path) {
  if (data == null) return false;

  final keys = path.split('.');
  dynamic current = data;

  for (final key in keys) {
    if (current == null) return false;

    // Handle list index access
    if (current is List) {
      final index = int.tryParse(key);
      if (index == null || index < 0 || index >= current.length) {
        return false;
      }
      current = current[index];
    }
    // Handle map key access
    else if (current is Map) {
      if (!current.containsKey(key)) {
        return false;
      }
      current = current[key];
    }
    // Can't navigate further
    else {
      return false;
    }
  }

  return true;
}

/// Delete a value at a nested path
///
/// Returns true if the value was deleted, false if path doesn't exist.
///
/// Example:
/// ```dart
/// final data = {'user': {'name': 'John', 'age': 30}};
/// deleteNestedValue(data, 'user.age'); // true, data = {'user': {'name': 'John'}}
/// deleteNestedValue(data, 'user.email'); // false, path doesn't exist
/// ```
bool deleteNestedValue(dynamic data, String path) {
  if (data == null) return false;
  if (!(data is Map || data is List)) return false;

  final keys = path.split('.');
  if (keys.isEmpty) return false;

  dynamic current = data;

  // Navigate to parent of target
  for (int i = 0; i < keys.length - 1; i++) {
    final key = keys[i];

    if (current is List) {
      final index = int.tryParse(key);
      if (index == null || index < 0 || index >= current.length) {
        return false;
      }
      current = current[index];
    } else if (current is Map) {
      if (!current.containsKey(key)) {
        return false;
      }
      current = current[key];
    } else {
      return false;
    }
  }

  // Delete the final value
  final lastKey = keys.last;

  if (current is List) {
    final index = int.tryParse(lastKey);
    if (index == null || index < 0 || index >= current.length) {
      return false;
    }
    current.removeAt(index);
    return true;
  } else if (current is Map) {
    if (!current.containsKey(lastKey)) {
      return false;
    }
    current.remove(lastKey);
    return true;
  }

  return false;
}
