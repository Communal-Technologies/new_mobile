import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

/// Audit M39: pulls the capture/download/share/permission concern out of
/// the receipt screen's State class, where it occupied ~170 lines.
///
/// What it owns
/// ------------
/// - `captureImage`  — converts a `RepaintBoundary` widget to PNG bytes.
/// - `saveToGallery` — gallery write + cross-platform permission walk.
/// - `share`         — uses `share_plus` to open the share sheet.
///
/// All UI feedback (snackbars) is delegated back to the caller via the
/// `onMessage` callback so this helper stays UI-framework-agnostic from
/// the screen's perspective and can be unit-tested by stubbing the
/// callback.
class ReceiptExportHelper {
  const ReceiptExportHelper({required this.onMessage});

  /// Snackbar / toast hook. The helper invokes this with user-facing
  /// strings for permission denials, save failures, etc. The screen
  /// wires it to its own snackbar shower.
  final void Function(String message) onMessage;

  /// Captures the widget under [boundaryKey] (typically a
  /// `RepaintBoundary` wrapping the receipt card) as PNG bytes at 3×
  /// pixel ratio. Returns null on failure.
  Future<Uint8List?> captureImage(GlobalKey boundaryKey) async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Receipt capture failed: $e');
      return null;
    }
  }

  /// Writes the PNG bytes to the device gallery. Walks the platform's
  /// permission flow first; on permanent denial points the user at app
  /// settings via `openAppSettings()`. Reports the outcome through
  /// [onMessage].
  Future<void> saveToGallery(
    Uint8List bytes, {
    required String fileName,
  }) async {
    if (!await _ensureGalleryPermission()) {
      // Permission flow already messaged the user; nothing to do.
      return;
    }
    try {
      final result = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 100,
        name: fileName,
        isReturnImagePathOfIOS: true,
      );

      final success =
          (result['isSuccess'] ?? result['success'] ?? false) == true;
      if (!success) throw Exception(result);

      final savedPath =
          result['filePath'] ?? result['path'] ?? result['fileUri'];
      onMessage(savedPath != null
          ? 'Receipt saved to gallery\n$savedPath'
          : 'Receipt saved to gallery');
    } catch (e) {
      debugPrint('Receipt save failed: $e');
      onMessage('Unable to save receipt.');
    }
  }

  /// Opens the system share sheet with the PNG attached.
  Future<void> share(
    Uint8List bytes, {
    required String shareText,
    String fileName = 'communal_receipt.png',
  }) async {
    try {
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            mimeType: 'image/png',
            name: fileName,
          ),
        ],
        text: shareText,
      );
    } catch (e) {
      debugPrint('Receipt share failed: $e');
      onMessage('Unable to share receipt.');
    }
  }

  Future<bool> _ensureGalleryPermission() async {
    if (kIsWeb) return true;

    Future<bool> requestPermission(
      Permission permission, {
      bool treatLimitedAsGranted = false,
    }) async {
      final status = await permission.request();
      if (status.isGranted ||
          (treatLimitedAsGranted && status.isLimited == true)) {
        return true;
      }
      if (status.isPermanentlyDenied) {
        onMessage(
          'Permission permanently denied. Enable it from Settings to save receipts.',
        );
        await openAppSettings();
      }
      return false;
    }

    Future<bool> hasPermission(
      Permission permission, {
      bool treatLimitedAsGranted = false,
    }) async {
      final status = await permission.status;
      return status.isGranted ||
          (treatLimitedAsGranted && status.isLimited == true);
    }

    if (Platform.isIOS) {
      if (await hasPermission(
            Permission.photosAddOnly,
            treatLimitedAsGranted: true,
          ) ||
          await hasPermission(Permission.photos,
              treatLimitedAsGranted: true)) {
        return true;
      }
      if (await requestPermission(
        Permission.photosAddOnly,
        treatLimitedAsGranted: true,
      )) {
        return true;
      }
      if (await requestPermission(
        Permission.photos,
        treatLimitedAsGranted: true,
      )) {
        return true;
      }
      return false;
    }

    if (Platform.isAndroid) {
      // Android 10+: image_gallery_saver_plus uses MediaStore — no permission
      // needed for the photo library. Only the legacy ≤Android 9 storage
      // permission is requested as a fallback for older devices.
      if (await hasPermission(Permission.photos) ||
          await hasPermission(Permission.storage)) {
        return true;
      }
      if (await requestPermission(Permission.photos)) return true;
      if (await requestPermission(Permission.storage)) return true;
      return false;
    }

    if (await hasPermission(Permission.storage)) {
      return true;
    }

    return requestPermission(Permission.storage);
  }
}
