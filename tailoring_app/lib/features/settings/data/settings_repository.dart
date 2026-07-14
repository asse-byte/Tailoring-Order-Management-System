import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';

/// Compte opérateur (Gérant / Secrétaire) — géré depuis Paramètres.
class OperatorAccount {
  const OperatorAccount({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
  });

  final String id;
  final String username;
  final String name;
  final String role; // 'MANAGER' | 'SECRETARY'

  factory OperatorAccount.fromJson(Map<String, dynamic> json) {
    return OperatorAccount(
      id: json['id'] as String,
      username: json['username'] as String,
      name: (json['name'] as String?) ?? '',
      role: json['role'] as String,
    );
  }
}

/// REST repository pour /api/settings/* et /api/users (Paramètres).
class SettingsRepository {
  SettingsRepository({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// Identité publique de la boutique (nom + logo) — lisible sans
  /// authentification : l'écran de connexion l'affiche.
  Future<({String shopName, String? logoUrl, String promoGroupLink, String? themeColor})>
      publicSettings() async {
    final dynamic res = await _api.get('/api/settings/public');
    final String? logo = res['logo_url'] as String?;
    final String? theme = res['theme_color'] as String?;
    return (
      shopName: (res['shop_name'] as String?) ?? 'Rayan Couture',
      logoUrl: (logo != null && logo.isNotEmpty) ? logo : null,
      promoGroupLink: (res['promo_group_link'] as String?) ?? '',
      themeColor: (theme != null && theme.isNotEmpty) ? theme : null,
    );
  }

  /// Tous les réglages (gérant uniquement — 403 pour la secrétaire).
  Future<Map<String, dynamic>> privateSettings() async {
    final dynamic res = await _api.get('/api/settings/private');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<void> updateSettings({
    String? shopName,
    String? logoUrl,
    int? defaultPieceRate,
    String? promoGroupLink,
    String? themeColor,
  }) async {
    await _api.put('/api/settings/private', body: {
      if (shopName != null && shopName.isNotEmpty) 'shop_name': shopName,
      if (logoUrl != null) 'logo_url': logoUrl,
      if (defaultPieceRate != null) 'default_piece_rate': defaultPieceRate,
      if (promoGroupLink != null) 'promo_group_link': promoGroupLink,
      if (themeColor != null) 'theme_color': themeColor,
    });
  }

  /// Téléverse le logo; le serveur le compresse et génère une miniature.
  Future<String> uploadLogo(XFile file) async {
    final Uri uri = Uri.parse('${ApiClient.baseUrl}/api/upload');
    final String? jwt = await _api.token;
    final request = http.MultipartRequest('POST', uri);
    if (jwt != null) request.headers['Authorization'] = 'Bearer $jwt';
    
    final bytes = await file.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name,
      ),
    );
    
    final response = await request.send();
    final String body = await response.stream.bytesToString();
    if (response.statusCode >= 400) {
      String message = 'Échec du téléversement du logo.';
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['error'] is String) {
          message = decoded['error'] as String;
        }
      } catch (_) {/* keep default */}
      throw ApiException(response.statusCode, message);
    }
    return (jsonDecode(body) as Map<String, dynamic>)['url'] as String;
  }

  // ---- comptes opérateurs (gérant uniquement) ----

  Future<List<OperatorAccount>> listAccounts() async {
    final dynamic res = await _api.get('/api/users');
    return (res['items'] as List)
        .map((e) => OperatorAccount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> setAccountPassword(String userId, String newPassword) =>
      _api.put('/api/users/$userId/password',
          body: {'new_password': newPassword});
}
