import 'dart:ui';
import 'package:flutter/material.dart';

/// Suppress known Sembast web IndexedDB interop errors
///
/// These errors occur in Sembast's internal IndexedDB notification system on web
/// and don't affect actual cache operations. They are safe to suppress.
void suppressSembastWebErrors() {
  // Suppress synchronous Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    final error = details.exception.toString();
    if (_isSembastWebError(error)) {
      // Ignore Sembast web IndexedDB interop errors
      return;
    }
    FlutterError.presentError(details);
  };

  // Suppress async platform errors
  PlatformDispatcher.instance.onError = (error, stack) {
    final errorStr = error.toString();
    if (_isSembastWebError(errorStr)) {
      // Ignore Sembast web IndexedDB interop errors
      return true;
    }
    return false;
  };
}

bool _isSembastWebError(String error) {
  // Suppress all LegacyJavaScriptObject type errors from IndexedDB/Sembast
  if (error.contains('LegacyJavaScriptObject')) {
    return error.contains('NotificationRevision') ||
        error.contains('IdbCursorWithValue') ||
        error.contains('IdbObjectStore') ||
        error.contains('IdbTransaction') ||
        error.contains('sembast') ||
        error.contains('idb_shim');
  }
  return false;
}
