import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

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
  bool _loaded = false;

  String get shopName => _shopName;
  String? get logoUrl => _logoUrl;
  int get defaultPieceRate => _defaultPieceRate;
  String get promoGroupLink => _promoGroupLink;
  bool get loaded => _loaded;

  Future<void> refresh() async {
    try {
      final settings = await _repo.publicSettings();
      _shopName = settings.shopName;
      _logoUrl = settings.logoUrl;
      _promoGroupLink = settings.promoGroupLink;
      _loaded = true;
      notifyListeners();
    } catch (_) {
      // Serveur injoignable : on garde le nom par défaut
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
