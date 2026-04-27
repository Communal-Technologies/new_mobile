package com.example.communal_mobile

import android.graphics.Color
import android.graphics.RenderEffect
import android.graphics.Shader
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Extends `FlutterFragmentActivity` (rather than `FlutterActivity`) so the
 * audit M38 [BiometricKeyChannel] can host an `androidx.biometric`
 * `BiometricPrompt`, which requires a `FragmentActivity` host.
 *
 * ## Recents-snapshot privacy
 *
 * The audit's original recommendation was `FLAG_SECURE`, which gives a
 * black recents thumbnail. The user followed up asking for a *blurred*
 * thumbnail instead, so we drop `FLAG_SECURE` and apply a native overlay
 * in `onPause()` — the OS captures the recents snapshot between `onPause`
 * and `onStop`, so anything we add in `onPause` is what ends up in the
 * thumbnail.
 *
 * Trade-off: removing `FLAG_SECURE` re-enables user-initiated screenshots
 * and screen recording. Acceptable for now per product call; if PII-in-
 * screenshots becomes a concern, restore `window.setFlags(FLAG_SECURE,
 * FLAG_SECURE)` in `onCreate` and accept the black thumbnail.
 */
class MainActivity : FlutterFragmentActivity() {
    private var privacyOverlay: View? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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

    override fun onPause() {
        super.onPause()
        applyPrivacyShield()
    }

    override fun onResume() {
        super.onResume()
        removePrivacyShield()
    }

    private fun applyPrivacyShield() {
        // Android 12+ (API 31): real Gaussian blur via RenderEffect on
        // the decorView. The OS-captured recents thumbnail picks this
        // up because RenderEffect applies during the next draw, which
        // happens before the snapshot.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            window.decorView.setRenderEffect(
                RenderEffect.createBlurEffect(
                    25f,
                    25f,
                    Shader.TileMode.CLAMP,
                ),
            )
            return
        }

        // Pre-Android 12: no native blur API runs fast enough in the
        // pause/snapshot window. Fall back to a translucent neutral
        // overlay so the thumbnail at least doesn't expose live PII.
        if (privacyOverlay != null) return
        val decor = window.decorView as? ViewGroup ?: return
        val overlay = View(this).apply {
            setBackgroundColor(Color.argb(0xE6, 0xF2, 0xF2, 0xF6))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        }
        decor.addView(overlay)
        privacyOverlay = overlay
    }

    private fun removePrivacyShield() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            window.decorView.setRenderEffect(null)
            return
        }
        privacyOverlay?.let {
            (it.parent as? ViewGroup)?.removeView(it)
        }
        privacyOverlay = null
    }
}
