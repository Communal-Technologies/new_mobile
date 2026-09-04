import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The single [FlutterSecureStorage] configuration the app reads and writes
/// with. Every construction site must use it, because accessibility is set per
/// item on write: one caller left on the defaults re-creates the item with the
/// weaker attribute.
///
/// The plugin defaults Apple platforms to `kSecAttrAccessibleWhenUnlocked`,
/// which *migrates to a new device* — so `token`, `refresh_token` and `user_id`
/// were carried inside an encrypted device backup and restored onto whatever
/// hardware that backup was fed to. `first_unlock_this_device`
/// (`…AfterFirstUnlockThisDeviceOnly`) never leaves the device and is still
/// readable after a reboot, so proactive refresh from the background keeps
/// working. `synchronizable` is already false, so nothing was in iCloud
/// Keychain sync; this closes the backup path.
///
/// Changing this on an installed app does not sign anyone out: the plugin's
/// read query omits `kSecAttrAccessible` entirely, and its write deletes the
/// key across every accessibility value before re-inserting.
const FlutterSecureStorage appSecureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
  mOptions: MacOsOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);
