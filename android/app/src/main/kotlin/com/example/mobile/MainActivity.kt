package com.example.communal_mobile

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.RenderEffect
import android.graphics.Shader
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
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
 * The product call is a *blurred* recents thumbnail rather than the black
 * one `FLAG_SECURE` would give us — partly so user-initiated screenshots
 * and screen recording stay enabled.
 *
 * The original implementation called [setRenderEffect] (or added a
 * fresh overlay [View]) inside [onPause]. Both are *async-drawn*: they
 * request the next frame, but the OS snapshot is captured between
 * [onPause] and [onStop], so on slower devices (e.g. budget Android, the
 * reporter was on a TECNO KI5q) the snapshot reliably won the race and
 * captured the unblurred frame.
 *
 * This implementation pre-installs the privacy overlay once at activity
 * setup and only mutates an `alpha` property in the lifecycle hooks:
 *   - the overlay is already laid out and uploaded as a hardware layer,
 *     so the alpha flip is a compositor uniform change with no layout
 *     pass and no texture upload — visible on the very next vsync,
 *     well before the snapshot.
 *   - on API 31+ we additionally try to stretch a downscaled bitmap of
 *     the live decor view onto the overlay so the cover looks like a
 *     real blur of the moment-before content rather than a flat panel.
 *     This capture is best-effort: when [Bitmap.createBitmap] /
 *     [View.draw] don't have time to complete (e.g. activity already
 *     stopped), the overlay falls back to its frosted-default
 *     background and the snapshot is still privacy-protected.
 *   - the same hooks fire across [onUserLeaveHint] (earliest, for
 *     user-initiated home/recents), [onWindowFocusChanged]`(false)`
 *     (catches incoming-call / system-sheet focus loss) and [onPause]
 *     as the final backstop, so we get the most lead time available
 *     for that capture and alpha flip.
 *
 * Trade-off: removing `FLAG_SECURE` keeps screenshots / screen recording
 * enabled. If PII-in-screenshots ever becomes a concern, restore
 * `window.setFlags(FLAG_SECURE, FLAG_SECURE)` in [onCreate] and accept
 * the black thumbnail.
 */
class MainActivity : FlutterFragmentActivity() {
    private var privacyOverlay: ImageView? = null

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

        installPrivacyOverlay()
    }

    private fun installPrivacyOverlay() {
        if (privacyOverlay != null) return
        val decor = window.decorView as? ViewGroup ?: return
        val overlay = ImageView(this).apply {
            scaleType = ImageView.ScaleType.FIT_XY
            // Frosted-default background. Used directly when the live
            // capture below is unavailable (cold pause, capture failure)
            // and shows under the captured bitmap as a tinted backstop.
            setBackgroundColor(Color.argb(0xE6, 0xF2, 0xF2, 0xF6))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            alpha = 0f
            // Hardware layer: alpha mutations stay on the GPU as a
            // compositor uniform — no draw pass needed when we flip it.
            setLayerType(View.LAYER_TYPE_HARDWARE, null)
        }
        decor.addView(overlay)
        privacyOverlay = overlay
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Earliest hook for explicit user backgrounding (home / recents
        // gesture). Gives the snapshot capture maximum lead time.
        applyPrivacyShield()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        // Catches focus loss not covered by onUserLeaveHint — incoming
        // call, control center sheet, biometric prompt parent stays put
        // (the prompt itself is a child of this window so it does not
        // trigger focus loss).
        if (!hasFocus) {
            applyPrivacyShield()
        } else {
            removePrivacyShield()
        }
    }

    override fun onPause() {
        super.onPause()
        // Backstop in case neither prior hook fired (extremely rare,
        // e.g. system-initiated pause without focus change).
        applyPrivacyShield()
    }

    override fun onResume() {
        super.onResume()
        removePrivacyShield()
    }

    private fun applyPrivacyShield() {
        val overlay = privacyOverlay ?: return
        if (overlay.alpha == 1f) return

        captureDecorViewSmall()?.let { overlay.setImageBitmap(it) }

        // Bring overlay above any view Flutter inserted into decor in
        // the meantime (e.g. a platform view PiP container).
        overlay.bringToFront()
        overlay.alpha = 1f

        // API 31+: real Gaussian blur on the captured downscale, stacked
        // on top of the bilinear stretch. If the effect doesn't commit
        // before the snapshot the overlay still covers the frame —
        // blur quality degrades, privacy doesn't.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            overlay.setRenderEffect(
                RenderEffect.createBlurEffect(
                    25f,
                    25f,
                    Shader.TileMode.CLAMP,
                ),
            )
        }
    }

    private fun removePrivacyShield() {
        val overlay = privacyOverlay ?: return
        if (overlay.alpha == 0f) return
        overlay.alpha = 0f
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            overlay.setRenderEffect(null)
        }
    }

    /**
     * Synchronously capture decorView into a heavily downscaled
     * bitmap (1/16 each side). Bilinear stretching by the GPU when the
     * ImageView paints gives the "frosted glass" look the product wants
     * without any per-pixel CPU blur work.
     *
     * Note: Flutter draws into a SurfaceView on Android, which
     * `View.draw(canvas)` cannot read back — so the captured bitmap
     * mostly shows the activity chrome and our own backgrounds. That's
     * fine: the overlay's frosted background still covers the snapshot,
     * and on the brief in-app window the live RenderEffect blur is what
     * the user actually sees.
     */
    private fun captureDecorViewSmall(): Bitmap? {
        val decor = window.decorView
        val w = decor.width
        val h = decor.height
        if (w <= 0 || h <= 0) return null

        val scale = 16
        val targetW = (w / scale).coerceAtLeast(1)
        val targetH = (h / scale).coerceAtLeast(1)

        return try {
            val bitmap = Bitmap.createBitmap(targetW, targetH, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            // Scale the canvas so a single decor.draw lands the full
            // frame inside the small bitmap. View.draw is synchronous —
            // when it returns, the bitmap holds the snapshot.
            canvas.scale(1f / scale, 1f / scale)
            decor.draw(canvas)
            bitmap
        } catch (_: Throwable) {
            null
        }
    }
}
