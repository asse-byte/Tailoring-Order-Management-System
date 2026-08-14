import 'package:url_launcher/url_launcher.dart';

/// Shared WhatsApp deep-linking.
///
/// The shop contacts clients through `wa.me` links opened on the device — the
/// only flow that works without a paid provider account (see
/// `backend/src/services/whatsapp.js` for why server-side sending is not the
/// path shops actually use).
///
/// This lives in `core/` because the same normalisation is needed from the
/// clients list, the client detail screen and the unpaid-order reminders;
/// `InvoiceService` keeps its own order-specific messages and calls in here for
/// the number handling.

/// Normalise a typed phone number to the international digits `wa.me` expects.
///
/// Mali local numbers are 8 digits and get the 223 country code. Returns null
/// when there are not enough digits to be a real number, so callers can warn
/// instead of opening WhatsApp on nothing.
String? waPhone(String? raw) {
  if (raw == null) return null;
  var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.length == 8) digits = '223$digits';
  return digits.length >= 8 ? digits : null;
}

/// True when a number is usable for WhatsApp — for hiding the button.
bool canWhatsApp(String? raw) => waPhone(raw) != null;

/// Opens a WhatsApp conversation with [phone], optionally prefilling [text].
/// Returns false if the number is unusable or no WhatsApp/browser handled it.
Future<bool> openWhatsApp(String? phone, {String? text}) async {
  final String? normalised = waPhone(phone);
  if (normalised == null) return false;
  final String query =
      (text == null || text.isEmpty) ? '' : '?text=${Uri.encodeComponent(text)}';
  return launchUrl(
    Uri.parse('https://wa.me/$normalised$query'),
    mode: LaunchMode.externalApplication,
  );
}

/// The polite French reminder sent for an order delivered but not fully paid.
String unpaidReminderMessage({
  required String clientName,
  required String shopName,
  required String resteFormatted,
}) {
  return 'Bonjour $clientName,\n\n'
      'Nous espérons que votre commande vous plaît !\n'
      'Il reste un solde de $resteFormatted à régler pour cette commande.\n\n'
      'Vous pouvez passer à l\'atelier quand cela vous arrange.\n'
      'Merci beaucoup pour votre confiance.\n\n'
      '$shopName';
}
