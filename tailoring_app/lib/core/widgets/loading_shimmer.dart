import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';

/// Shimmer placeholder helpers for loading states.
class LoadingShimmer {
  LoadingShimmer._();

  static Widget box({
    double height = 16,
    double width = double.infinity,
    BorderRadius? borderRadius,
  }) {
    return _ShimmerBase(
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }

  static Widget orderCard() {
    return _ShimmerBase(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                          height: 14, width: 120, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Container(
                          height: 12, width: 80, color: Colors.grey.shade300),
                    ],
                  ),
                ),
                Container(
                  height: 22,
                  width: 64,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
                height: 10,
                width: double.infinity,
                color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Container(height: 10, width: 200, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }

  static Widget list({int count = 4}) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => orderCard(),
    );
  }
}

class _ShimmerBase extends StatelessWidget {
  const _ShimmerBase({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: dark ? AppColors.darkSurfaceAlt : const Color(0xFFE7EAEE),
      highlightColor: dark ? AppColors.darkBorder : const Color(0xFFF5F7FA),
      child: child,
    );
  }
}
