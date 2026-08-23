import 'package:flutter/material.dart';

import '../../../core/theme/couture_icons.dart';

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
  ///
  /// The stored NAMES are the contract with the database and never change; only
  /// the glyph each one draws moved to the app's single icon family, so a shop
  /// that already picked 'watch' keeps its watch.
  static const Map<String, IconData> iconChoices = <String, IconData>{
    'spray': CoutureIcons.sprayBottle,
    'shoe': CoutureIcons.sneaker,
    'fabric': CoutureIcons.stack,
    'watch': CoutureIcons.watch,
    'hat': CoutureIcons.baseballCap,
    'bag': CoutureIcons.handbag,
    'glasses': CoutureIcons.eyeglasses,
    'jewel': CoutureIcons.diamond,
    'shirt': CoutureIcons.tShirt,
    'box': CoutureIcons.package,
  };

  IconData get iconData => iconChoices[icon] ?? CoutureIcons.tag;
}
