/// Utilities for nested data structures using dot notation paths.
///
/// Example: "user.name" -> data['user']['name']
library;

/// Get value from nested structure using dot notation.
///
/// Example:
/// ```dart
/// final data = {'user': {'name': 'John'}};
/// getNestedValue(data, 'user.name'); // 'John'
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

/// Set value in nested structure using dot notation.
///
/// Creates intermediate maps/lists as needed. Returns true if successful.
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

/// Check if nested path exists.
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

/// Delete value at nested path.
///
/// Returns true if deleted, false if path doesn't exist.
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
