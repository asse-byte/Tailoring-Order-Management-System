import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import '../../data/products_repository.dart';
import '../../domain/product.dart';

class ProductsProvider extends ChangeNotifier {
  final ProductsRepository _repo;

  ProductsProvider({ProductsRepository? repository})
      : _repo = repository ?? ProductsRepository();

  List<Product> _items = [];
  bool _loading = false;
  String? _error;
  String _category = 'all';
  bool _hasMore = true;

  List<Product> get items => _items;
  bool get loading => _loading;
  String? get error => _error;
  String get category => _category;
  bool get hasMore => _hasMore;

  static const int _pageSize = 20;

  Future<void> refresh() => loadProducts(clear: true);

  Future<void> setCategory(String newCategory) async {
    if (_category == newCategory) return;
    _category = newCategory;
    notifyListeners();
    await refresh();
  }

  Future<void> loadProducts({bool clear = false}) async {
    if (_loading) return;
    if (clear) {
      _items = [];
      _hasMore = true;
    }
    if (!_hasMore) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final List<Product> page = await _repo.list(
        category: _category,
        limit: _pageSize,
        offset: _items.length,
      );
      _items.addAll(page);
      _hasMore = page.length == _pageSize;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> addProduct({
    required String name,
    required String category,
    required double price,
    double costPrice = 0,
    required int quantity,
    required int lowStockThreshold,
    required List<Map<String, String>> images,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final p = await _repo.create(
        name: name,
        category: category,
        price: price,
        costPrice: costPrice,
        quantity: quantity,
        lowStockThreshold: lowStockThreshold,
        images: images,
      );
      _items.insert(0, p);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> editProduct(
    String id, {
    required String name,
    required String category,
    required double price,
    double costPrice = 0,
    required int quantity,
    required int lowStockThreshold,
    required List<Map<String, String>> images,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final p = await _repo.update(
        id,
        name: name,
        category: category,
        price: price,
        costPrice: costPrice,
        quantity: quantity,
        lowStockThreshold: lowStockThreshold,
        images: images,
      );
      final idx = _items.indexWhere((x) => x.id == id);
      if (idx != -1) {
        _items[idx] = p;
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteProduct(String id) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _repo.delete(id);
      _items.removeWhere((x) => x.id == id);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> sellProduct(String productId, int quantity) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _repo.sellProduct(productId: productId, quantity: quantity);
      // Update local product stock
      final idx = _items.indexWhere((x) => x.id == productId);
      if (idx != -1) {
        final current = _items[idx];
        _items[idx] = Product(
          id: current.id,
          name: current.name,
          category: current.category,
          price: current.price,
          costPrice: current.costPrice,
          quantity: (current.quantity - quantity).clamp(0, 9999999),
          lowStockThreshold: current.lowStockThreshold,
          images: current.images,
        );
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Map<String, String>?> uploadImage(XFile file) async {
    try {
      return await _repo.uploadImage(file);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
}
