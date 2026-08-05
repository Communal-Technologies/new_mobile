package elite.codec.communal

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.RenderEffect
import android.graphics.Shader
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.view.PixelCopy
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.view.WindowManager
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
 * Product call: a *blurred* recents thumbnail rather than the black one
 * `FLAG_SECURE` would give us — partly so user-initiated screenshots and
 * screen recording stay enabled.
 *
 * Why View.draw is not enough: Flutter renders into a [android.view.SurfaceView]
 * on Android. `View.draw(canvas)` does not read back surface content, so a
 * synchronous capture of the decor view returns mostly empty chrome — the
 * overlay would just show its frosted default background, not a real blur
 * of the live UI.
 *
 * What we do instead:
 *  - Pre-install a full-screen [ImageView] overlay during
 *    [configureFlutterEngine], kept invisible (alpha=0) during normal use.
 *    Toggling alpha is a compositor uniform — no layout, no async draw,
 *    visible on the next vsync.
 *  - While the activity is foregrounded, schedule periodic [PixelCopy]
 *    captures of the live window surface (which DOES include the Flutter
 *    SurfaceView). The captured bitmap is downscaled aggressively
 *    (1/8 each side); when the [ImageView] paints it stretched across the
 *    screen the GPU's bilinear filter gives the "frosted glass" look.
 *  - On any "we're about to be backgrounded" hook ([onUserLeaveHint],
 *    [onWindowFocusChanged]`(false)`, [onPause] as backstop): set the
 *    cached blurred bitmap on the overlay and flip alpha to 1.
 *  - On API 31+ also stack a real [RenderEffect] Gaussian blur on the
 *    [ImageView] for extra polish.
 *
 * The cached bitmap is at most [CAPTURE_REFRESH_INTERVAL_MS] stale; if the
 * user navigates and immediately backgrounds we may briefly show an older
 * screen blurred — acceptable trade-off vs. the perf cost of capturing
 * every frame.
 *
 * Trade-off (unchanged from before): no `FLAG_SECURE`, so screenshots and
 * screen recording stay enabled. Restore it in [onCreate] if PII-in-
 * screenshots becomes a concern.
 */
class MainActivity : FlutterFragmentActivity() {
    private var privacyOverlay: ImageView? = null
    private var cachedBlurredBitmap: Bitmap? = null

    /**
     * Dedicated background thread for [PixelCopy.request]'s callback.
     * Using the main looper for the callback risks blocking the UI
     * thread on slow captures; PixelCopy itself is hardware-accelerated
     * and runs off the calling thread.
     */
    private var captureThread: HandlerThread? = null
    private var captureBackgroundHandler: Handler? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val refreshCaptureRunnable = object : Runnable {
        override fun run() {
            captureLiveContent()
            mainHandler.postDelayed(this, CAPTURE_REFRESH_INTERVAL_MS)
        }
    }

    companion object {
        /**
         * How often to refresh the cached blur capture while the
         * activity is foregrounded. Shorter = less stale blur in
         * recents but more PixelCopy work; longer = staler capture if
         * the user navigated since the last refresh. 2.5s is the
         * compromise we landed on.
         */
        private const val CAPTURE_REFRESH_INTERVAL_MS = 2500L

        /**
         * 1/8 each side → 1/64 of the original pixel count. For a 1080×2400
         * screen that's a 135×300 bitmap — cheap to capture and to upload
         * to the GPU. Bilinear stretch when the ImageView paints hides the
         * pixelation and looks like a frosted blur.
         */
        private const val CAPTURE_SCALE_DIVISOR = 8
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Apply FLAG_SECURE from the stored preference BEFORE Flutter
        // initialises. The flutter shared_preferences plugin stores keys with
        // a "flutter." prefix in the "FlutterSharedPreferences" file.
        // Default is false (screenshots not allowed) → secure by default.
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val allowScreenshot = prefs.getBoolean("flutter.allow_screenshot", false)
        if (!allowScreenshot) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE,
            )
        }
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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "elite.codec.communal/screenshot",
        ).setMethodCallHandler { call, result ->
            if (call.method == "setScreenshotEnabled") {
                val enabled = call.argument<Boolean>("enabled") ?: false
                runOnUiThread {
                    if (enabled) {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.setFlags(
                            WindowManager.LayoutParams.FLAG_SECURE,
                            WindowManager.LayoutParams.FLAG_SECURE,
                        )
                    }
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }

        installPrivacyOverlay()
    }

    private fun installPrivacyOverlay() {
        if (privacyOverlay != null) return
        val decor = window.decorView as? ViewGroup ?: return
        val overlay = ImageView(this).apply {
            scaleType = ImageView.ScaleType.FIT_XY
            // Fully opaque frosted-default background. Used directly
            // when the cached capture isn't ready yet (cold pause
            // before the first PixelCopy completes) and shows under
            // the captured bitmap as a backstop in case any pixels of
            // that bitmap come through transparent. 0xFF alpha matters
            // — at 0xE6 (~90 %) the underlying activity bled through
            // and the cover looked see-through.
            setBackgroundColor(Color.argb(0xFF, 0xF2, 0xF2, 0xF6))
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
        // gesture). Gives the OS snapshot the most lead time to capture
        // the overlay.
        applyPrivacyShield()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        // Important: do NOT apply the shield on focus loss. The OS
        // biometric prompt and other in-process system sheets (e.g.
        // notification shade pulldown) take the activity's window
        // focus *without* backgrounding the app — if we shield here,
        // the user sees the privacy cover under the biometric dialog.
        // Real backgrounding is caught by onUserLeaveHint and onPause.
        //
        // We still defensively remove the shield on focus regain, in
        // case onResume / onUserLeaveHint state got desynced.
        if (hasFocus) {
            removePrivacyShield()
        }
    }

    override fun onResume() {
        super.onResume()
        removePrivacyShield()
        startCaptureLoop()
    }

    override fun onPause() {
        super.onPause()
        applyPrivacyShield()
        stopCaptureLoop()
    }

    override fun onDestroy() {
        stopCaptureLoop()
        captureThread?.quitSafely()
        captureThread = null
        captureBackgroundHandler = null
        cachedBlurredBitmap?.recycle()
        cachedBlurredBitmap = null
        super.onDestroy()
    }

    private fun startCaptureLoop() {
        if (captureThread == null) {
            captureThread = HandlerThread("communal-pixel-copy").also {
                it.start()
                captureBackgroundHandler = Handler(it.looper)
            }
        }
        mainHandler.removeCallbacks(refreshCaptureRunnable)
        // First capture after a frame so Flutter has time to paint
        // following the resume.
        mainHandler.postDelayed(refreshCaptureRunnable, 250L)
    }

    private fun stopCaptureLoop() {
        mainHandler.removeCallbacks(refreshCaptureRunnable)
    }

    private fun captureLiveContent() {
        // PixelCopy.request(Window, ...) and PixelCopy.request(SurfaceView, ...)
        // are both API 24+, but the SurfaceView overload is the one we need:
        // Flutter renders into a SurfaceView under decor view, and the Window
        // PixelCopy variant returns transparent pixels for SurfaceView regions
        // on many devices — leaving the cached bitmap mostly empty and the
        // overlay looking like a flat frosted panel rather than a blur of the
        // live UI. Targeting the SurfaceView directly reads its surface buffer
        // and gives us actual Flutter content to blur.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        val backgroundHandler = captureBackgroundHandler ?: return

        val flutterSurface = findFlutterSurfaceView(window.decorView) ?: return
        val w = flutterSurface.width
        val h = flutterSurface.height
        if (w <= 0 || h <= 0) return

        val targetW = (w / CAPTURE_SCALE_DIVISOR).coerceAtLeast(1)
        val targetH = (h / CAPTURE_SCALE_DIVISOR).coerceAtLeast(1)

        val bitmap = try {
            Bitmap.createBitmap(targetW, targetH, Bitmap.Config.ARGB_8888)
        } catch (_: Throwable) {
            return
        }

        try {
            PixelCopy.request(
                flutterSurface,
                bitmap,
                { result ->
                    // Callback runs on the background handler. Only
                    // touch state we know is safe across threads —
                    // writing to `cachedBlurredBitmap` is fine because
                    // applyPrivacyShield reads it on the main thread
                    // after the OS lifecycle hop, never concurrently.
                    if (result == PixelCopy.SUCCESS) {
                        val previous = cachedBlurredBitmap
                        cachedBlurredBitmap = bitmap
                        previous?.recycle()
                    } else {
                        bitmap.recycle()
                    }
                },
                backgroundHandler,
            )
        } catch (_: Throwable) {
            bitmap.recycle()
        }
    }

    /**
     * Walk the view tree under [root] looking for the first [SurfaceView] —
     * Flutter's `FlutterSurfaceView` (or whatever underlying surface
     * platform views may have inserted; we prefer Flutter's by depth and
     * size). We don't rely on Flutter's class names because they live in
     * an internal package and have shifted across releases.
     */
    private fun findFlutterSurfaceView(root: View): SurfaceView? {
        if (root is SurfaceView) return root
        if (root is ViewGroup) {
            for (i in 0 until root.childCount) {
                val match = findFlutterSurfaceView(root.getChildAt(i))
                if (match != null) return match
            }
        }
        return null
    }

    private fun applyPrivacyShield() {
        val overlay = privacyOverlay ?: return
        if (overlay.alpha == 1f) return

        cachedBlurredBitmap?.let { overlay.setImageBitmap(it) }

        // Bring overlay above any view Flutter inserted into decor in
        // the meantime (e.g. a platform view container).
        overlay.bringToFront()
        overlay.alpha = 1f

        // API 31+: real Gaussian blur on the bilinear-stretched bitmap
        // for a smoother look. If the effect doesn't commit before the
        // snapshot the bitmap is still visible — blur quality degrades,
        // privacy doesn't.
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
}
