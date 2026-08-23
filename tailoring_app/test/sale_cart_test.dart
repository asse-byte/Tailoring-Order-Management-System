// =============================================================================
// The counter basket — the arithmetic the seller reads off the screen.
// =============================================================================
// The total shown at the till is what the customer is asked to pay, so it has
// to be right before anything reaches the server. These tests pin the exact
// scenario the owner described: two ready-to-wear pieces, a cap, shoes, a
// perfume and a watch, in one sale.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:tailoring_app/features/products/domain/sale_cart.dart';

CartLine _product(String id, String name, int price,
        {int qty = 1, int? stock}) =>
    CartLine(
      kind: 'produit',
      itemId: id,
      name: name,
      unitPrice: price,
      quantity: qty,
      stockLeft: stock,
    );

CartLine _model(String id, String name, int price, {int qty = 1}) => CartLine(
      kind: 'pret_a_porter',
      itemId: id,
      name: name,
      unitPrice: price,
      quantity: qty,
    );

void main() {
  test('the owner’s basket adds up to the hand-computed total', () {
    final cart = SaleCart()
      ..add(_model('m1', 'Boubou brodé', 60000, qty: 2))
      ..add(_product('p1', 'Bonnet', 5000, stock: 10))
      ..add(_product('p2', 'Chaussures', 30000, stock: 10))
      ..add(_product('p3', 'Parfum', 15000, stock: 10))
      ..add(_product('p4', 'Montre', 40000, stock: 10));

    // 2×60 000 + 5 000 + 30 000 + 15 000 + 40 000 = 210 000
    expect(cart.total, 210000);
    expect(cart.itemCount, 6);
    expect(cart.lineCount, 5);
  });

  test('tapping the same product twice means two of it, not two lines', () {
    final cart = SaleCart()
      ..add(_product('p1', 'Parfum', 15000, stock: 10))
      ..add(_product('p1', 'Parfum', 15000, stock: 10));

    expect(cart.lineCount, 1);
    expect(cart.quantityOf('produit', 'p1'), 2);
    expect(cart.total, 30000);
  });

  test('a product and a model sharing an id stay separate lines', () {
    // Ids come from two different tables, so identity is (kind, id).
    final cart = SaleCart()
      ..add(_product('same-id', 'Parfum', 10000, stock: 5))
      ..add(_model('same-id', 'Boubou', 60000));

    expect(cart.lineCount, 2);
    expect(cart.total, 70000);
  });

  test('setting a quantity to zero removes the line', () {
    final cart = SaleCart()
      ..add(_product('p1', 'Parfum', 15000, stock: 10))
      ..add(_product('p2', 'Montre', 40000, stock: 10));

    cart.setQuantity(0, 0);
    expect(cart.lineCount, 1);
    expect(cart.total, 40000);
  });

  test('a counter discount changes only that line', () {
    final cart = SaleCart()
      ..add(_product('p1', 'Parfum', 15000, stock: 10))
      ..add(_product('p2', 'Montre', 40000, stock: 10));

    cart.setUnitPrice(0, 12000); // VIP price, owner decision 2026-08-03
    expect(cart.total, 52000);
    expect(cart.lines[1].unitPrice, 40000);
  });

  test('asking for more than the shelf holds is flagged before checkout', () {
    final cart = SaleCart()..add(_product('p1', 'Sandale', 20000, stock: 2));
    expect(cart.hasStockProblem, isFalse);

    cart.setQuantity(0, 3);
    expect(cart.hasStockProblem, isTrue);
    expect(cart.lines.first.exceedsStock, isTrue);
  });

  test('ready-to-wear has no stock ceiling', () {
    final cart = SaleCart()..add(_model('m1', 'Boubou', 60000, qty: 50));
    expect(cart.hasStockProblem, isFalse);
  });

  test('the API payload carries the price actually charged', () {
    final cart = SaleCart()..add(_product('p1', 'Parfum', 15000, stock: 10));
    cart.setUnitPrice(0, 9000);

    expect(cart.toApiLines(), <Map<String, dynamic>>[
      <String, dynamic>{
        'kind': 'produit',
        'item_id': 'p1',
        'qty': 1,
        'unit_price': 9000,
      },
    ]);
  });

  test('clearing empties the basket and notifies once', () {
    int notifications = 0;
    final cart = SaleCart()..addListener(() => notifications++);
    cart.add(_product('p1', 'Parfum', 15000, stock: 10));
    notifications = 0;

    cart.clear();
    expect(cart.isEmpty, isTrue);
    expect(cart.total, 0);
    expect(notifications, 1);

    cart.clear(); // already empty — nothing to tell the UI about
    expect(notifications, 1);
  });
}
