# PVCache

**Encrypted caching for Flutter** — Built on HiveHook with AES-256 encryption and smart key rotation.

## Features

- **AES-256 encryption**: Automatic encrypt/decrypt with secure key storage
- **Smart key rotation**: Three strategies (passive, active, reactive)
- **Fast & lightweight**: Uses HiveHook’s hook-based cache engine
- **Cross-platform**: Web, iOS, Android, Desktop
- **Simple API**: Minimal setup, maximum security

## Installation

- Add `pvcache: ^1.0.0` to your app’s `pubspec.yaml` dependencies.
- Run `flutter pub get`.

Note: PVCache re-exports HiveHook APIs, so you typically only need to depend on `pvcache`.

## Quick Start

1. Import PVCache (it re-exports HiveHook).
2. Create an encrypted hook plugin using `createEncryptedHook()`.
3. Register your cache environment with `PVCache.registerConfig(...)` and include the plugin.
4. Initialize HiveHook once via `HHiveCore.initialize()`.
5. Retrieve a cache with `PVCache.getCache(env)` and use HiveHook’s normal `put/get/delete` APIs.

That’s it — values stored through the encrypted hook are encrypted at rest and transparently decrypted on reads.

## Key Rotation

PVCache handles corrupted or invalid encryption keys gracefully:

**Automatic (recommended)**
- `KeyRotationStrategy.active`: automatically rotates the key when decryption fails.

**Manual Control**
- `KeyRotationStrategy.passive`: rotation is manual (you decide when to rotate).

**Custom Logic**
- `KeyRotationStrategy.reactive`: you provide a callback to decide whether rotation should occur.

## Advanced Usage

**Bring Your Own Key**
- Provide a 32-byte (256-bit) key to `createEncryptedHook(providedKey: ...)`.

**Multiple Encrypted Caches**
- Set default plugins once, then register multiple environments; each environment gets its own cache instance.

**Ephemeral Cache** (new key each launch)
- Enable `autoResetKey` to discard the stored key on launch and generate a new one.

## How It Works

PVCache extends [HiveHook](https://pub.dev/packages/hivehook) with encryption:
- Data is encrypted with AES-256-CBC before storage
- Keys are stored securely via Flutter Secure Storage
- Decryption happens automatically on read
- Invalid keys trigger your chosen rotation strategy

## License

MIT

