import Flutter
import Foundation
import LocalAuthentication
import Security

/// Audit M38: native bridge for biometric-bound ECDSA P-256 key
/// generation + signing via the Secure Enclave (`kSecAttrTokenIDSecureEnclave`).
///
/// Channel: `communal/biometric_keys`
///
/// Each enrolled device has a key whose tag is `KEY_TAG_PREFIX + deviceId`
/// (UTF-8). The key is generated with:
///   - `.privateKeyUsage` — sign / verify only.
///   - `.biometryCurrentSet` — every signing operation requires a fresh
///     biometric prompt, AND the key is permanently invalidated by the
///     Secure Enclave the moment the user enrols / removes a Face ID or
///     Touch ID. Subsequent signing attempts fail with
///     `errSecAuthFailed` and the mobile app re-enrols against the
///     backend.
///
/// The matching private key cannot be exported. Only the SubjectPublicKey
/// (DER-encoded SubjectPublicKeyInfo, then PEM-wrapped) is returned to
/// Dart and uploaded to the backend during enrollment.
class BiometricKeyChannel: NSObject {

    static let channelName = "communal/biometric_keys"
    private static let keyTagPrefix = "elite.codec.communal.biometric."

    private let methodChannel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        self.methodChannel = FlutterMethodChannel(name: BiometricKeyChannel.channelName,
                                                  binaryMessenger: messenger)
        super.init()
        self.methodChannel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = (call.arguments as? [String: Any]) ?? [:]
        switch call.method {
        case "isAvailable":
            result(isStrongBiometricAvailable())
        case "generateKeyPair":
            guard let deviceId = args["deviceId"] as? String, !deviceId.isEmpty else {
                return result(FlutterError(code: "ARG", message: "deviceId required", details: nil))
            }
            generateKeyPair(deviceId: deviceId, result: result)
        case "getPublicKeyPem":
            guard let deviceId = args["deviceId"] as? String, !deviceId.isEmpty else {
                return result(FlutterError(code: "ARG", message: "deviceId required", details: nil))
            }
            result(getPublicKeyPem(deviceId: deviceId))
        case "signWithBiometric":
            guard let deviceId = args["deviceId"] as? String, !deviceId.isEmpty,
                  let payload = args["payload"] as? String else {
                return result(FlutterError(code: "ARG", message: "deviceId + payload required",
                                           details: nil))
            }
            let title = (args["promptTitle"] as? String) ?? "Confirm with biometrics"
            let subtitle = (args["promptSubtitle"] as? String)
                ?? "Verify it's you to authorize this transaction"
            signWithBiometric(deviceId: deviceId, payload: payload,
                              promptTitle: title, promptSubtitle: subtitle, result: result)
        case "revoke":
            guard let deviceId = args["deviceId"] as? String, !deviceId.isEmpty else {
                return result(FlutterError(code: "ARG", message: "deviceId required", details: nil))
            }
            revokeKey(deviceId: deviceId)
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Availability

    private func isStrongBiometricAvailable() -> Bool {
        let ctx = LAContext()
        var err: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
    }

    // MARK: - Key generation

    private func generateKeyPair(deviceId: String, result: @escaping FlutterResult) {
        let tag = self.tagData(deviceId)
        // Drop any previous key at the same tag — re-enrollment after
        // biometric reset is the canonical path here.
        self.deleteKey(tag: tag)

        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            &error
        ) else {
            let msg = (error?.takeRetainedValue() as Error?)?.localizedDescription ?? "access control failed"
            return result(FlutterError(code: "NATIVE", message: msg, details: nil))
        }

        let privateAttrs: [String: Any] = [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: tag,
            kSecAttrAccessControl as String: access,
        ]
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: privateAttrs,
        ]
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            let msg = (error?.takeRetainedValue() as Error?)?.localizedDescription ?? "key gen failed"
            return result(FlutterError(code: "NATIVE", message: msg, details: nil))
        }
        guard let publicKey = SecKeyCopyPublicKey(privateKey),
              let pem = self.publicKeyPem(from: publicKey) else {
            return result(FlutterError(code: "NATIVE", message: "could not export public key",
                                       details: nil))
        }
        result(pem)
    }

    private func getPublicKeyPem(deviceId: String) -> String? {
        let tag = self.tagData(deviceId)
        guard let privateKey = self.loadPrivateKey(tag: tag),
              let publicKey = SecKeyCopyPublicKey(privateKey) else {
            return nil
        }
        return self.publicKeyPem(from: publicKey)
    }

    // MARK: - Signing

    private func signWithBiometric(deviceId: String, payload: String,
                                   promptTitle: String, promptSubtitle: String,
                                   result: @escaping FlutterResult) {
        let tag = self.tagData(deviceId)
        // Run on a background queue so the system biometric prompt UI is
        // not blocked by Flutter's dart isolate awaiting the result.
        DispatchQueue.global(qos: .userInitiated).async {
            let context = LAContext()
            context.localizedReason = promptSubtitle
            // localizedFallbackTitle = "" disables the system's
            // "Use Passcode" fallback so the prompt is biometric-only,
            // matching the audit's "fresh biometric" requirement.
            context.localizedFallbackTitle = ""

            // Bind LAContext to the key lookup so the next access
            // triggers the prompt synchronously here.
            let query: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrApplicationTag as String: tag,
                kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                kSecReturnRef as String: true,
                kSecUseAuthenticationContext as String: context,
                kSecUseOperationPrompt as String: promptTitle,
            ]
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            guard status == errSecSuccess, let privateKey = item else {
                let code = self.osStatusToCode(status)
                DispatchQueue.main.async {
                    result(FlutterError(code: code,
                                        message: "Key lookup failed (status \(status))",
                                        details: nil))
                }
                return
            }
            // swiftlint:disable:next force_cast
            let key = privateKey as! SecKey

            var error: Unmanaged<CFError>?
            guard let data = payload.data(using: .utf8) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "ARG", message: "payload not utf-8", details: nil))
                }
                return
            }
            guard let signature = SecKeyCreateSignature(
                key,
                .ecdsaSignatureMessageX962SHA256,
                data as CFData,
                &error
            ) else {
                let nsError = error?.takeRetainedValue() as Error?
                let code = self.cfErrorToCode(nsError)
                DispatchQueue.main.async {
                    result(FlutterError(code: code,
                                        message: nsError?.localizedDescription ?? "sign failed",
                                        details: nil))
                }
                return
            }
            let b64 = (signature as Data).base64EncodedString()
            DispatchQueue.main.async {
                result(b64)
            }
        }
    }

    // MARK: - Revocation

    private func revokeKey(deviceId: String) {
        deleteKey(tag: self.tagData(deviceId))
    }

    private func deleteKey(tag: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Lookup helpers

    private func loadPrivateKey(tag: Data) -> SecKey? {
        // No LAContext attached here — used only for non-signing operations
        // (public-key export). The Secure Enclave doesn't require biometric
        // to copy the public key.
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let key = item else { return nil }
        return (key as! SecKey)
    }

    private func tagData(_ deviceId: String) -> Data {
        return (BiometricKeyChannel.keyTagPrefix + deviceId).data(using: .utf8)!
    }

    // MARK: - Public key → PEM

    /// Wraps the Secure Enclave's raw X9.63 uncompressed P-256 public key
    /// in a DER-encoded SubjectPublicKeyInfo, then base64-PEM. Backend
    /// `openssl_pkey_get_public` ingests this directly.
    private func publicKeyPem(from publicKey: SecKey) -> String? {
        var error: Unmanaged<CFError>?
        guard let raw = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return nil
        }
        // raw layout for a P-256 public key: 0x04 | X (32 bytes) | Y (32 bytes) = 65 bytes total.
        guard raw.count == 65, raw[0] == 0x04 else { return nil }

        // SubjectPublicKeyInfo prefix for ecPublicKey + P-256 + a 65-byte
        // uncompressed BIT STRING. Constructed once as a byte literal —
        // RFC 5480 §2.1.1 / §2.2.
        let prefix: [UInt8] = [
            0x30, 0x59,                                     // SEQUENCE (89 bytes)
            0x30, 0x13,                                     //   SEQUENCE (19 bytes)
            0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01,  //     OID ecPublicKey
            0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, // OID secp256r1
            0x03, 0x42, 0x00,                                //   BIT STRING (66 bytes; leading 0)
        ]
        var spki = Data(prefix)
        spki.append(raw)

        let base64 = spki.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        return "-----BEGIN PUBLIC KEY-----\n\(base64)\n-----END PUBLIC KEY-----\n"
    }

    // MARK: - Error mapping

    private func osStatusToCode(_ status: OSStatus) -> String {
        switch status {
        case errSecItemNotFound: return "NOT_ENROLLED"
        case errSecAuthFailed:   return "USER_CANCELED"
        case errSecUserCanceled: return "USER_CANCELED"
        default:                 return "BIOMETRIC_ERROR"
        }
    }

    private func cfErrorToCode(_ error: Error?) -> String {
        guard let nsErr = error as NSError? else { return "BIOMETRIC_ERROR" }
        // LAErrors come through as the LAErrorDomain.
        if nsErr.domain == LAErrorDomain {
            switch LAError.Code(rawValue: nsErr.code) {
            case .userCancel?, .systemCancel?, .appCancel?: return "USER_CANCELED"
            case .biometryLockout?:                          return "LOCKOUT"
            case .biometryNotAvailable?, .biometryNotEnrolled?: return "UNAVAILABLE"
            default: break
            }
        }
        return "BIOMETRIC_ERROR"
    }
}
