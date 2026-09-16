/// Nigerian mobile networks, told apart by the number's NCC-allocated prefix.
///
/// The prefix is the first four digits of the local form (`0803…`), and five for
/// the `0702x` block Smile shares with MTN, so the network is known long before
/// the eleventh digit.
enum NgMobileNetwork {
  mtn('MTN'),
  airtel('Airtel'),
  glo('Glo'),
  nineMobile('9mobile');

  const NgMobileNetwork(this.label);

  final String label;

  /// Whether a biller's display name is this network.
  bool matchesProvider(String providerName) {
    final n = providerName.toLowerCase().replaceAll(' ', '');
    return switch (this) {
      NgMobileNetwork.mtn => n.contains('mtn'),
      NgMobileNetwork.airtel => n.contains('airtel'),
      NgMobileNetwork.glo => n.contains('glo'),
      NgMobileNetwork.nineMobile =>
        n.contains('9mobile') || n.contains('etisalat'),
    };
  }
}

const Map<String, NgMobileNetwork> _fiveDigitPrefixes = {
  '07025': NgMobileNetwork.mtn,
  '07026': NgMobileNetwork.mtn,
};

const Map<String, NgMobileNetwork> _fourDigitPrefixes = {
  '0703': NgMobileNetwork.mtn,
  '0704': NgMobileNetwork.mtn,
  '0706': NgMobileNetwork.mtn,
  '0707': NgMobileNetwork.mtn,
  '0803': NgMobileNetwork.mtn,
  '0806': NgMobileNetwork.mtn,
  '0810': NgMobileNetwork.mtn,
  '0813': NgMobileNetwork.mtn,
  '0814': NgMobileNetwork.mtn,
  '0816': NgMobileNetwork.mtn,
  '0903': NgMobileNetwork.mtn,
  '0906': NgMobileNetwork.mtn,
  '0913': NgMobileNetwork.mtn,
  '0916': NgMobileNetwork.mtn,
  '0701': NgMobileNetwork.airtel,
  '0708': NgMobileNetwork.airtel,
  '0802': NgMobileNetwork.airtel,
  '0808': NgMobileNetwork.airtel,
  '0812': NgMobileNetwork.airtel,
  '0901': NgMobileNetwork.airtel,
  '0902': NgMobileNetwork.airtel,
  '0904': NgMobileNetwork.airtel,
  '0907': NgMobileNetwork.airtel,
  '0911': NgMobileNetwork.airtel,
  '0912': NgMobileNetwork.airtel,
  '0705': NgMobileNetwork.glo,
  '0805': NgMobileNetwork.glo,
  '0807': NgMobileNetwork.glo,
  '0811': NgMobileNetwork.glo,
  '0815': NgMobileNetwork.glo,
  '0905': NgMobileNetwork.glo,
  '0915': NgMobileNetwork.glo,
  '0809': NgMobileNetwork.nineMobile,
  '0817': NgMobileNetwork.nineMobile,
  '0818': NgMobileNetwork.nineMobile,
  '0908': NgMobileNetwork.nineMobile,
  '0909': NgMobileNetwork.nineMobile,
};

/// The local `0XXXXXXXXXX` form of a Nigerian mobile number as far as it has
/// been typed: `+234803…`, `234803…` and `803…` all become `0803…`.
String ngLocalPhone(String raw) {
  var d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('234')) d = '0${d.substring(3)}';
  if (d.isNotEmpty && '789'.contains(d[0])) d = '0$d';
  return d;
}

/// The network a (possibly partial) number belongs to, or null while the prefix
/// is still too short or is not a mobile allocation.
NgMobileNetwork? detectNgMobileNetwork(String raw) {
  final local = ngLocalPhone(raw);
  if (local.length >= 5) {
    final five = _fiveDigitPrefixes[local.substring(0, 5)];
    if (five != null) return five;
  }
  if (local.length >= 4) return _fourDigitPrefixes[local.substring(0, 4)];
  return null;
}
