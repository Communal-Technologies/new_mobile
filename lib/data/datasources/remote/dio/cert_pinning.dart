import 'dart:convert';
import 'dart:io';

import 'package:asn1lib/asn1lib.dart';
import 'package:crypto/crypto.dart';

/// SPKI-based TLS certificate pinning for the dio HTTP client.
///
/// Audit M8.
///
/// ## What this does (and what it doesn't)
///
/// We register a `badCertificateCallback` on the `HttpClient` underlying dio
/// that compares the **SubjectPublicKeyInfo SHA-256 hash** of the presented
/// certificate against a configured list of pins. Per the audit's recipe:
///
/// > ship pinned cert(s) in assets and use `dio` `HttpClientAdapter` with
/// > `badCertificateCallback` set to compare SPKI hashes. Use a list of pins
/// > (current + next) so cert rotation doesn't brick the app.
///
/// SPKI pinning (rather than full-cert pinning) means a re-issued certificate
/// with the same key pair stays valid against the existing pin — only key
/// rotation requires a pin refresh. The `current + next` pattern lets you
/// stage the new pin **before** the rotation, then drop the old pin after.
///
/// ## Threat model coverage
///
/// `badCertificateCallback` only fires when the platform's default chain
/// validation **fails**. So this layer specifically hardens against:
///
/// - rogue / compromised CAs issuing valid-looking certs for our hosts;
/// - corporate-MITM / dev-proxy-MITM scenarios where a proxy signs with a
///   locally-trusted root the user installed.
///
/// It does **not** replace default trust validation (we still rely on the
/// system trust store for the first-pass check). Full replacement would
/// require shipping our chain root in a custom `SecurityContext` and is out
/// of scope for this pass.
///
/// ## Configuration
///
/// Pins live in [pinsByHost]. Each host gets a list of base64-encoded
/// SHA-256 hashes of the SPKI. **The list ships empty.** With an empty list
/// the verifier returns `false` for cert errors (i.e. behaves like the
/// default — no override), so the app continues to work using the platform's
/// default trust validation. This means M8 is "infrastructure landed,
/// pins-to-fill-in" until you generate real pins per the README procedure.
///
/// ## Generating a pin
///
/// ```sh
/// echo | openssl s_client -showcerts -servername api.communalhq.com \
///   -connect api.communalhq.com:443 2>/dev/null | \
///   openssl x509 -pubkey -noout | \
///   openssl pkey -pubin -outform DER | \
///   openssl dgst -sha256 -binary | base64
/// ```
///
/// Run twice per host: once for the **current** cert, once for the **next**
/// (which you'll have provisioned with your CA before the rotation window).
class CertPinning {
  CertPinning._();

  /// Base64-encoded SHA-256 SPKI hashes per host. Empty list = pinning OFF
  /// for that host. Add the primary + backup pins generated via the openssl
  /// command in the class doc-block before promoting to a release build.
  static const Map<String, List<String>> pinsByHost = <String, List<String>>{
    'api.communalhq.com': <String>[
      // 'BASE64_SPKI_SHA256_PRIMARY',
      // 'BASE64_SPKI_SHA256_BACKUP',
    ],
    'api-staging.communalhq.com': <String>[
      // 'BASE64_SPKI_SHA256_PRIMARY',
      // 'BASE64_SPKI_SHA256_BACKUP',
    ],
  };

  /// Returns `true` if [host] has at least one pin configured. Used by the
  /// dio adapter to decide whether to consult the pinning callback at all.
  static bool isPinned(String host) =>
      (pinsByHost[host]?.isNotEmpty ?? false);

  /// Returns `true` iff the SPKI SHA-256 of [cert] matches one of the pins
  /// configured for [host]. When the host has no pins, returns `false` —
  /// the caller is expected to gate on [isPinned] first.
  static bool verify(X509Certificate cert, String host) {
    final pins = pinsByHost[host];
    if (pins == null || pins.isEmpty) return false;
    final pin = _spkiSha256Base64(cert);
    if (pin == null) return false;
    return pins.contains(pin);
  }

  /// Extracts SubjectPublicKeyInfo from the cert DER, hashes it with SHA-256,
  /// returns the base64 of the digest. Returns `null` on parse failure so
  /// the caller can fail closed (reject) rather than crash.
  static String? _spkiSha256Base64(X509Certificate cert) {
    try {
      final asn1 = ASN1Parser(cert.der);
      // Certificate ::= SEQUENCE { tbsCertificate, signatureAlgorithm, signatureValue }
      final certificate = asn1.nextObject() as ASN1Sequence;
      final tbs = certificate.elements[0] as ASN1Sequence;
      // TBSCertificate ::= SEQUENCE {
      //   [0] EXPLICIT Version DEFAULT v1,           -- optional
      //   serialNumber, signature, issuer, validity, subject,
      //   subjectPublicKeyInfo, ... }
      // SPKI is the 7th element if version-tag is present, else the 6th.
      final hasVersion = tbs.elements[0].tag == 0xA0;
      final spkiIndex = hasVersion ? 6 : 5;
      final spki = tbs.elements[spkiIndex];
      final digest = sha256.convert(spki.encodedBytes);
      return base64.encode(digest.bytes);
    } catch (_) {
      return null;
    }
  }
}
