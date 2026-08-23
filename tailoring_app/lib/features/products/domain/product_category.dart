import 'package:flutter/material.dart';

/// A product type the SHOP defines (`product_categories`, migration 026).
///
/// The app used to hardcode Parfums / Chaussures / Tissus in three places, so
/// selling watches meant editing the code. The list is fetched now, and this
/// class only maps the stored [icon] name onto a glyph — an unknown icon falls
/// back to a neutral one rather than breaking a type the owner just invented.
class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.slug,
    required this.label,
    this.icon,
    this.sortOrder = 100,
    this.productsCount = 0,
  });

  final String id;
  final String slug;
  final String label;
  final String? icon;
  final int sortOrder;
  final int productsCount;

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      icon: json['icon']?.toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 100,
      productsCount: (json['products_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Names the manager can pick from when creating a type. Kept small and
  /// concrete on purpose: a long list of abstract glyphs is harder to choose
  /// from than a short list of recognisable objects.
  static const Map<String, IconData> iconChoices = <String, IconData>{
    'spray': Icons.local_florist_rounded,
    'shoe': Icons.ice_skating_rounded,
    'fabric': Icons.layers_rounded,
    'watch': Icons.watch_rounded,
    'hat': Icons.emoji_people_rounded,
    'bag': Icons.shopping_bag_rounded,
    'glasses': Icons.remove_red_eye_rounded,
    'jewel': Icons.diamond_rounded,
    'shirt': Icons.checkroom_rounded,
    'box': Icons.inventory_2_rounded,
  };

  IconData get iconData =>
      iconChoices[icon] ?? Icons.sell_rounded;
}
