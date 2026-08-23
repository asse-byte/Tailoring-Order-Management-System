class Supplier {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String notes;
  final int totalDebt;

  const Supplier({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.notes,
    required this.totalDebt,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        address: json['address'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        totalDebt: (json['total_debt'] as num?)?.toInt() ?? 0,
      );
}

class SupplierPurchase {
  final String id;
  final String? supplierId;
  final String supplierName;
  final bool supplierDeleted;
  final String description;
  final int totalAmount;
  final int advanceAmount;
  final int paidTotal;
  final int reste;
  final String purchaseDate;

  const SupplierPurchase({
    required this.id,
    this.supplierId,
    required this.supplierName,
    required this.supplierDeleted,
    required this.description,
    required this.totalAmount,
    required this.advanceAmount,
    required this.paidTotal,
    required this.reste,
    required this.purchaseDate,
  });

  factory SupplierPurchase.fromJson(Map<String, dynamic> json) =>
      SupplierPurchase(
        id: json['id'] as String,
        supplierId: json['supplier_id'] as String?,
        supplierName: json['supplier_name'] as String? ?? 'Fournisseur',
        supplierDeleted: json['supplier_deleted'] as bool? ?? false,
        description: json['description'] as String? ?? '',
        totalAmount: (json['total_amount'] as num?)?.toInt() ?? 0,
        advanceAmount: (json['advance_amount'] as num?)?.toInt() ?? 0,
        paidTotal: (json['paid_total'] as num?)?.toInt() ?? 0,
        reste: (json['reste'] as num?)?.toInt() ?? 0,
        purchaseDate: json['purchase_date'] as String? ?? '',
      );
}

class SupplierPayment {
  final String id;
  final String purchaseId;
  final int amount;
  final bool voided;
  final bool corrected;
  final String paidAt;
  final String? note;
  final String createdByName;

  const SupplierPayment({
    required this.id,
    required this.purchaseId,
    required this.amount,
    required this.voided,
    required this.corrected,
    required this.paidAt,
    this.note,
    required this.createdByName,
  });

  factory SupplierPayment.fromJson(Map<String, dynamic> json) =>
      SupplierPayment(
        id: json['id'] as String,
        purchaseId: json['purchase_id'] as String,
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        voided: json['voided'] as bool? ?? false,
        corrected: json['corrected'] as bool? ?? false,
        paidAt: json['paid_at'] as String? ?? '',
        note: json['note'] as String?,
        createdByName: json['created_by_name'] as String? ?? '',
      );
}

class WholesaleOrderItem {
  final String model;
  final int qty;
  final int unitPrice;

  const WholesaleOrderItem({
    required this.model,
    required this.qty,
    required this.unitPrice,
  });

  int get total => qty * unitPrice;

  factory WholesaleOrderItem.fromJson(Map<String, dynamic> json) =>
      WholesaleOrderItem(
        model: json['model'] as String? ?? '',
        qty: (json['qty'] as num?)?.toInt() ?? 0,
        unitPrice: (json['unit_price'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'model': model,
        'qty': qty,
        'unit_price': unitPrice,
      };
}

class WholesaleOrder {
  final String id;
  final String merchantName;
  final String merchantPhone;
  final List<WholesaleOrderItem> items;
  final int totalAmount;
  final int advanceAmount;
  final int paidTotal;
  final int reste;
  final String status; // 'en_cours' | 'livre'
  final String orderDate;
  final String? deliveredDate;
  final String? notes;

  const WholesaleOrder({
    required this.id,
    required this.merchantName,
    required this.merchantPhone,
    required this.items,
    required this.totalAmount,
    required this.advanceAmount,
    required this.paidTotal,
    required this.reste,
    required this.status,
    required this.orderDate,
    this.deliveredDate,
    this.notes,
  });

  factory WholesaleOrder.fromJson(Map<String, dynamic> json) => WholesaleOrder(
        id: json['id'] as String,
        merchantName: json['merchant_name'] as String? ?? 'Commerçant',
        merchantPhone: json['merchant_phone'] as String? ?? '',
        items: (json['items'] as List? ?? [])
            .map((e) => WholesaleOrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalAmount: (json['total_amount'] as num?)?.toInt() ?? 0,
        advanceAmount: (json['advance_amount'] as num?)?.toInt() ?? 0,
        paidTotal: (json['paid_total'] as num?)?.toInt() ?? 0,
        reste: (json['reste'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'en_cours',
        orderDate: json['order_date'] as String? ?? '',
        deliveredDate: json['delivered_date'] as String?,
        notes: json['notes'] as String?,
      );
}

class WholesalePayment {
  final String id;
  final String orderId;
  final int amount;
  final bool voided;
  final bool corrected;
  final String paidAt;
  final String? note;
  final String createdByName;

  const WholesalePayment({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.voided,
    required this.corrected,
    required this.paidAt,
    this.note,
    required this.createdByName,
  });

  factory WholesalePayment.fromJson(Map<String, dynamic> json) =>
      WholesalePayment(
        id: json['id'] as String,
        orderId: json['order_id'] as String,
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        voided: json['voided'] as bool? ?? false,
        corrected: json['corrected'] as bool? ?? false,
        paidAt: json['paid_at'] as String? ?? '',
        note: json['note'] as String?,
        createdByName: json['created_by_name'] as String? ?? '',
      );
}
