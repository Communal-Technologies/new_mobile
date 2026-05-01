package elite.codec.communal

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.util.concurrent.Executors
import android.util.Base64

/**
 * Audit M38: native bridge for biometric-bound ECDSA P-256 key
 * generation + signing via the Android Keystore.
 *
 * Channel: `communal/biometric_keys`
 *
 * Each enrolled device has a key under the alias
 * `KEY_ALIAS_PREFIX + deviceId`. The key is configured so:
 *   - Every signing operation requires a fresh biometric prompt
 *     (`setUserAuthenticationRequired(true)`).
 *   - The key is permanently invalidated by Keystore the moment the
 *     user enrols a new fingerprint or face
 *     (`setInvalidatedByBiometricEnrollment(true)`). Subsequent signing
 *     attempts will throw `KeyPermanentlyInvalidatedException` and the
 *     mobile app re-enrols against the backend.
 *
 * The matching private key cannot be exported. Only the SubjectPublicKey
 * (in DER, then PEM-wrapped) is returned to Dart and uploaded to the
 * backend during enrollment.
 */
class BiometricKeyChannel(private val activity: FragmentActivity) : MethodCallHandler {

    private val executor = Executors.newSingleThreadExecutor()

    fun register(channel: MethodChannel) {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            when (call.method) {
                "isAvailable" -> result.success(isStrongBiometricAvailable())
                "generateKeyPair" -> {
                    val deviceId = call.argument<String>("deviceId")
                        ?: return result.error("ARG", "deviceId required", null)
                    result.success(generateKeyPair(deviceId))
                }
                "getPublicKeyPem" -> {
                    val deviceId = call.argument<String>("deviceId")
                        ?: return result.error("ARG", "deviceId required", null)
                    result.success(getPublicKeyPem(deviceId))
                }
                "signWithBiometric" -> {
                    val deviceId = call.argument<String>("deviceId")
                        ?: return result.error("ARG", "deviceId required", null)
                    val payload = call.argument<String>("payload")
                        ?: return result.error("ARG", "payload required", null)
                    val title = call.argument<String>("promptTitle")
                        ?: "Confirm with biometrics"
                    val subtitle = call.argument<String>("promptSubtitle")
                        ?: "Verify it's you to authorize this transaction"
                    val negative = call.argument<String>("promptNegativeButton") ?: "Cancel"
                    signWithBiometric(deviceId, payload, title, subtitle, negative, result)
                }
                "revoke" -> {
                    val deviceId = call.argument<String>("deviceId")
                        ?: return result.error("ARG", "deviceId required", null)
                    revokeKey(deviceId)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            result.error("NATIVE", e.message ?: e.javaClass.simpleName, null)
        }
    }

    private fun isStrongBiometricAvailable(): Boolean {
        val mgr = BiometricManager.from(activity)
        // BIOMETRIC_STRONG is required for keys gated on user auth.
        return mgr.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) ==
            BiometricManager.BIOMETRIC_SUCCESS
    }

    /**
     * Generates a fresh ECDSA P-256 keypair under the device's alias and
     * returns the public key as a PEM string. If a key already exists at
     * that alias we delete it first — re-enrollment after biometric reset
     * is the canonical path here, and we want the new key to win.
     */
    private fun generateKeyPair(deviceId: String): String {
        val alias = aliasFor(deviceId)
        val ks = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        if (ks.containsAlias(alias)) {
            ks.deleteEntry(alias)
        }

        val gen = KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_EC,
            KEYSTORE,
        )
        val spec = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY,
        )
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setUserAuthenticationRequired(true)
            // Key dies the instant a new biometric is enrolled — forces
            // explicit re-enrollment via the backend, which is the audit's
            // M38 recommendation.
            .setInvalidatedByBiometricEnrollment(true)
            .build()
        gen.initialize(spec)
        gen.generateKeyPair()

        return getPublicKeyPem(deviceId)
            ?: throw IllegalStateException("Key generation succeeded but public key not retrievable.")
    }

    private fun getPublicKeyPem(deviceId: String): String? {
        val ks = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        val alias = aliasFor(deviceId)
        val cert = ks.getCertificate(alias) ?: return null
        val publicKey = cert.publicKey
        val der = publicKey.encoded // X.509 SubjectPublicKeyInfo, DER-encoded
        val base64 = Base64.encodeToString(der, Base64.NO_WRAP)
        // PEM-wrap so the backend's openssl_pkey_get_public can ingest it
        // directly. Standard 64-char line breaks.
        val wrapped = base64.chunked(64).joinToString("\n")
        return "-----BEGIN PUBLIC KEY-----\n$wrapped\n-----END PUBLIC KEY-----\n"
    }

    /**
     * Prompts the biometric and signs `payload` with the device's key.
     * Returns the base64 of the DER-encoded ECDSA signature.
     *
     * The result is delivered asynchronously — Flutter awaits the channel
     * call until [Result.success] or [Result.error] fires from the
     * BiometricPrompt callbacks.
     */
    private fun signWithBiometric(
        deviceId: String,
        payload: String,
        title: String,
        subtitle: String,
        negativeButton: String,
        flutterResult: Result,
    ) {
        val ks = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        val alias = aliasFor(deviceId)
        val privateKey = (ks.getEntry(alias, null) as? KeyStore.PrivateKeyEntry)
            ?.privateKey
            ?: return flutterResult.error("NOT_ENROLLED", "No key for $deviceId", null)

        val signature = Signature.getInstance("SHA256withECDSA").apply {
            initSign(privateKey)
        }

        val cryptoObject = BiometricPrompt.CryptoObject(signature)

        val prompt = BiometricPrompt(
            activity,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    res: BiometricPrompt.AuthenticationResult,
                ) {
                    try {
                        val sig = res.cryptoObject?.signature
                            ?: return flutterResult.error("SIGN", "no signature in crypto object", null)
                        sig.update(payload.toByteArray(Charsets.UTF_8))
                        val der = sig.sign()
                        val b64 = Base64.encodeToString(der, Base64.NO_WRAP)
                        activity.runOnUiThread { flutterResult.success(b64) }
                    } catch (e: Throwable) {
                        activity.runOnUiThread {
                            flutterResult.error("SIGN", e.message ?: "sign failed", null)
                        }
                    }
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    activity.runOnUiThread {
                        flutterResult.error(
                            errorCodeToString(errorCode),
                            errString.toString(),
                            mapOf("errorCode" to errorCode),
                        )
                    }
                }

                override fun onAuthenticationFailed() {
                    // User-recoverable — fingerprint not recognized. Don't
                    // resolve the channel call yet; the prompt stays open
                    // for retry.
                }
            },
        )

        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .setSubtitle(subtitle)
            // Strong-only — matches the keys we generate
            // (setUserAuthenticationRequired requires STRONG).
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .setNegativeButtonText(negativeButton)
            .build()

        activity.runOnUiThread {
            prompt.authenticate(info, cryptoObject)
        }
    }

    private fun revokeKey(deviceId: String) {
        val ks = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        val alias = aliasFor(deviceId)
        if (ks.containsAlias(alias)) {
            ks.deleteEntry(alias)
        }
    }

    private fun aliasFor(deviceId: String): String = "$KEY_ALIAS_PREFIX$deviceId"

    private fun errorCodeToString(code: Int): String = when (code) {
        BiometricPrompt.ERROR_USER_CANCELED,
        BiometricPrompt.ERROR_NEGATIVE_BUTTON -> "USER_CANCELED"
        BiometricPrompt.ERROR_LOCKOUT,
        BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> "LOCKOUT"
        BiometricPrompt.ERROR_NO_BIOMETRICS,
        BiometricPrompt.ERROR_HW_NOT_PRESENT,
        BiometricPrompt.ERROR_HW_UNAVAILABLE -> "UNAVAILABLE"
        else -> "BIOMETRIC_ERROR"
    }

    companion object {
        private const val KEYSTORE = "AndroidKeyStore"
        private const val KEY_ALIAS_PREFIX = "communal_biometric_"
        const val CHANNEL = "communal/biometric_keys"
    }
}
