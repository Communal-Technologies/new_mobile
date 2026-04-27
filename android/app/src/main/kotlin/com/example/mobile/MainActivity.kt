package com.example.communal_mobile

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Extends `FlutterFragmentActivity` (rather than `FlutterActivity`) so the
 * audit M38 [BiometricKeyChannel] can host an `androidx.biometric`
 * `BiometricPrompt`, which requires a `FragmentActivity` host.
 */
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // FLAG_SECURE: tell Android never to capture this app's content for
        // the recents-list thumbnail (or for Assistant / accessibility
        // screenshots). Without this flag the OS snapshots the live frame
        // *before* Flutter's onPaused callback runs, so any Flutter-side
        // privacy blur is too late to protect the recents tile. With the
        // flag set, the recents tile is replaced with a blank surface
        // automatically by the system.
        //
        // Side effects:
        //   - User-initiated screenshots are blocked too (acceptable for a
        //     finance app; matches typical banking apps' behavior).
        //   - Screen recording stops capturing the app's content while it's
        //     in the foreground.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Audit M38: register the biometric key channel so Dart can
        // generate / sign / revoke ECDSA P-256 keys via the platform's
        // hardware-backed Keystore.
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BiometricKeyChannel.CHANNEL,
        )
        BiometricKeyChannel(this).register(channel)
    }
}
