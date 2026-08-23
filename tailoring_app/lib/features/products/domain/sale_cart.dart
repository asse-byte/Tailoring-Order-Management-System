import 'package:flutter/foundation.dart';

/// One line waiting in the counter basket.
///
/// [kind] is the API's discriminator: 'produit' for a stocked product,
/// 'pret_a_porter' for a ready-made model (which has no stock).
@immutable
class CartLine {
  const CartLine({
    required this.kind,
    required this.itemId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.imageUrl,
    this.stockLeft,
  });

  final String kind;
  final String itemId;
  final String name;
  final int unitPrice;
  final int quantity;
  final String? imageUrl;

  /// Units on the shelf, for products only. Null for ready-to-wear models,
  /// which are made to order and never run out.
  final int? stockLeft;

  int get lineTotal => unitPrice * quantity;

  /// True when the basket already holds more of this item than the shop has.
  bool get exceedsStock => stockLeft != null && quantity > stockLeft!;

  CartLine copyWith({int? quantity, int? unitPrice}) => CartLine(
        kind: kind,
        itemId: itemId,
        name: name,
        unitPrice: unitPrice ?? this.unitPrice,
        quantity: quantity ?? this.quantity,
        imageUrl: imageUrl,
        stockLeft: stockLeft,
      );

  Map<String, dynamic> toApiLine() => <String, dynamic>{
        'kind': kind,
        'item_id': itemId,
        'qty': quantity,
        'unit_price': unitPrice,
      };

  /// Same item = same kind AND same id. A perfume and a model could in
  /// principle share a uuid across two tables, so the kind is part of identity.
  bool isSameItem(CartLine other) =>
      other.kind == kind && other.itemId == itemId;
}

/// The basket for one trip to the till.
///
/// Lives in a [ChangeNotifier] rather than screen state so the running total
/// survives navigating between the product tabs while shopping.
class SaleCart extends ChangeNotifier {
  final List<CartLine> _lines = <CartLine>[];

  List<CartLine> get lines => List<CartLine>.unmodifiable(_lines);
  bool get isEmpty => _lines.isEmpty;
  bool get isNotEmpty => _lines.isNotEmpty;

  /// Distinct lines, not units — this is what the basket badge shows.
  int get lineCount => _lines.length;

  int get itemCount => _lines.fold(0, (sum, l) => sum + l.quantity);
  int get total => _lines.fold(0, (sum, l) => sum + l.lineTotal);

  /// True when any line asks for more than the shelf holds. Checkout is
  /// blocked on it so the seller finds out here rather than from a 409 after
  /// the customer has already been quoted a total.
  bool get hasStockProblem => _lines.any((l) => l.exceedsStock);

  int quantityOf(String kind, String itemId) {
    for (final l in _lines) {
      if (l.kind == kind && l.itemId == itemId) return l.quantity;
    }
    return 0;
  }

  /// Adding the same item again bumps its quantity instead of making a second
  /// line — a seller tapping a product twice means "two of these".
  void add(CartLine line) {
    final int i = _lines.indexWhere((l) => l.isSameItem(line));
    if (i >= 0) {
      _lines[i] = _lines[i].copyWith(quantity: _lines[i].quantity + line.quantity);
    } else {
      _lines.add(line);
    }
    notifyListeners();
  }

  /// Setting a quantity to 0 (or below) removes the line.
  void setQuantity(int index, int quantity) {
    if (index < 0 || index >= _lines.length) return;
    if (quantity <= 0) {
      _lines.removeAt(index);
    } else {
      _lines[index] = _lines[index].copyWith(quantity: quantity);
    }
    notifyListeners();
  }

  /// A discount the shop grants at the counter (owner decision 2026-08-03:
  /// the seller may set the unit price, with no ceiling).
  void setUnitPrice(int index, int unitPrice) {
    if (index < 0 || index >= _lines.length || unitPrice < 0) return;
    _lines[index] = _lines[index].copyWith(unitPrice: unitPrice);
    notifyListeners();
  }

  void removeAt(int index) {
    if (index < 0 || index >= _lines.length) return;
    _lines.removeAt(index);
    notifyListeners();
  }

  void clear() {
    if (_lines.isEmpty) return;
    _lines.clear();
    notifyListeners();
  }

  List<Map<String, dynamic>> toApiLines() =>
      _lines.map((l) => l.toApiLine()).toList();
}
