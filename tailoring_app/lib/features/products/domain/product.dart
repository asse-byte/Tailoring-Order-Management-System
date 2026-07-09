class ProductImage {
  final String id;
  final String url;
  final String? thumbUrl;

  const ProductImage({
    required this.id,
    required this.url,
    this.thumbUrl,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: json['id'] as String,
      url: json['url'] as String,
      thumbUrl: json['thumb_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'thumb_url': thumbUrl,
      };
}

class Product {
  final String id;
  final String category; // 'parfum' | 'chaussure' | 'tissu'
  final String name;
  final double price;
  final double costPrice;
  final int quantity;
  final int lowStockThreshold;
  final List<ProductImage> images;

  const Product({
    required this.id,
    required this.category,
    required this.name,
    required this.price,
    this.costPrice = 0,
    required this.quantity,
    required this.lowStockThreshold,
    required this.images,
  });

  bool get isLowStock => quantity <= lowStockThreshold;

  /// Profit per unit = selling price - cost price
  double get profit => price - costPrice;

  factory Product.fromJson(Map<String, dynamic> json) {
    final List<dynamic> imgsJson = json['images'] as List<dynamic>? ?? [];
    return Product(
      id: json['id'] as String,
      category: json['category'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0,
      quantity: json['quantity'] as int,
      lowStockThreshold: json['low_stock_threshold'] as int? ?? 3,
      images: imgsJson.map((e) => ProductImage.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'name': name,
        'price': price,
        'cost_price': costPrice,
        'quantity': quantity,
        'low_stock_threshold': lowStockThreshold,
        'images': images.map((e) => e.toJson()).toList(),
      };
}
