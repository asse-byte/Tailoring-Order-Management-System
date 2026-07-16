import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/web_helper.dart';
import '../../data/settings_repository.dart';

/// Identité de la boutique (nom + logo), chargée depuis les réglages
/// publics : affichée sur l'écran de connexion, le titre de l'app et le
/// tableau de bord. Rafraîchie après toute modification dans Paramètres.
class ShopSettingsProvider extends ChangeNotifier {
  ShopSettingsProvider({SettingsRepository? repository})
      : _repo = repository ?? SettingsRepository() {
    refresh();
  }

  final SettingsRepository _repo;

  String _shopName = 'Rayan Couture';
  String? _logoUrl;
  int _defaultPieceRate = 0;
  String _promoGroupLink = '';
  String _themeColorHex = '#1E293B';
  bool _loaded = false;

  String get shopName => _shopName;
  String? get logoUrl => _logoUrl;
  int get defaultPieceRate => _defaultPieceRate;
  String get promoGroupLink => _promoGroupLink;
  bool get loaded => _loaded;

  /// The shop's brand colour (item 9). Falls back to the house Deep Teal when
  /// unset or malformed, so the UI always has a valid primary.
  String get themeColorHex => _themeColorHex;
  Color get themeColor => _parseHex(_themeColorHex) ?? AppColors.primary;

  static Color? _parseHex(String? hex) {
    if (hex == null) return null;
    final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(hex.trim());
    if (m == null) return null;
    return Color(int.parse('FF${m.group(1)}', radix: 16));
  }

  void _updateWebTab() {
    updateWebTabFaviconAndTitle(_logoUrl, _shopName);
  }

  Future<void> refresh() async {
    try {
      final settings = await _repo.publicSettings();
      _shopName = settings.shopName;
      _logoUrl = settings.logoUrl;
      _promoGroupLink = settings.promoGroupLink;
      if (settings.themeColor != null) _themeColorHex = settings.themeColor!;
      _loaded = true;
      notifyListeners();
      _updateWebTab();
    } catch (_) {
      // Serveur injoignable : on garde le nom par défaut
    }
  }

  Future<bool> updateThemeColor(String hex) async {
    try {
      await _repo.updateSettings(themeColor: hex);
      _themeColorHex = hex;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updatePromoGroupLink(String link) async {
    try {
      await _repo.updateSettings(promoGroupLink: link);
      _promoGroupLink = link;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> fetchPrivateSettings() async {
    try {
      final private = await _repo.privateSettings();
      _defaultPieceRate = (private['default_piece_rate'] as num?)?.toInt() ?? 0;
      notifyListeners();
    } catch (_) {
      // Échec du chargement des réglages privés
    }
  }

  Future<bool> updateShopName(String name) async {
    try {
      await _repo.updateSettings(shopName: name);
      _shopName = name;
      notifyListeners();
      _updateWebTab();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> uploadAndSetLogo(XFile file) async {
    try {
      final String logoUrl = await _repo.uploadLogo(file);
      await _repo.updateSettings(logoUrl: logoUrl);
      _logoUrl = logoUrl;
      notifyListeners();
      _updateWebTab();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateDefaultPieceRate(int rate) async {
    try {
      await _repo.updateSettings(defaultPieceRate: rate);
      _defaultPieceRate = rate;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
