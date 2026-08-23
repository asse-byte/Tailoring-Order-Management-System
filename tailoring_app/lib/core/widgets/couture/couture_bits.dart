import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../theme/couture_icons.dart';
import '../../theme/couture_palette.dart';

/// The small shared pieces every redesigned screen needs: a card, a search
/// field, a filter chip, a status pill, an empty state.
///
/// These are NEW widgets sitting beside `status_badge.dart` / `empty_state.dart`
/// rather than edits to them, for the same reason `CouturePalette` sits beside
/// `AppColors`: the old ones are still on every screen that has not been
/// redesigned, and restyling those from here would change screens nobody has
/// looked at. They come out when the last screen moves.

/// A white card with a warm hairline. No accent stripe down the left edge —
/// that is the single most recognisable tell of a generated interface.
class CoutureCard extends StatelessWidget {
  const CoutureCard({super.key, required this.child, this.onTap, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final CoutureScheme c = CoutureScheme.of(context);
    final Widget body = Padding(
      padding: padding ?? const EdgeInsets.all(CouturePalette.s4),
      child: child,
    );
    return Material(
      color: c.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.line),
      ),
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );
  }
}

/// The pale square an icon sits in.
class CoutureWash extends StatelessWidget {
  const CoutureWash({
    super.key,
    required this.icon,
    this.tone = CoutureTone.normal,
    this.size = 44,
    this.iconSize = 22,
  });

  final IconData icon;
  final CoutureTone tone;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final CoutureScheme c = CoutureScheme.of(context);
    final (Color wash, Color glyph) = switch (tone) {
      CoutureTone.normal => (c.iconWash, c.iconInk),
      CoutureTone.urgent => (c.urgentWash, c.urgentInk),
      CoutureTone.good => (c.goodWash, c.goodInk),
      CoutureTone.quiet => (c.quiet, c.inkSoft),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(size >= 40 ? 12 : 10),
      ),
      child: Icon(icon, size: iconSize, color: glyph),
    );
  }
}

enum CoutureTone { normal, urgent, good, quiet }

/// One search field, one behaviour, everywhere. The caller still owns the
/// controller and the debounce — this only decides how it looks.
class CoutureSearchField extends StatelessWidget {
  const CoutureSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.onClear,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  /// Fired when the seller presses the keyboard's search key. Optional: most
  /// screens debounce [onChanged] instead and never need it.
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final CoutureScheme c = CoutureScheme.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction:
          onSubmitted == null ? TextInputAction.done : TextInputAction.search,
      style: TextStyle(fontSize: 14.5, color: c.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 14, color: c.inkFaint),
        isDense: true,
        filled: true,
        fillColor: c.card,
        prefixIcon:
            Icon(CoutureIcons.magnifyingGlass, size: 19, color: c.inkFaint),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Effacer',
                icon: Icon(CoutureIcons.close, size: 17, color: c.inkFaint),
                onPressed: onClear,
              ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: CouturePalette.s3, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.iconInk, width: 1.4),
        ),
      ),
    );
  }
}

/// A filter chip. Selected is a filled pill in the icon tone, not a Material
/// blue — and its label goes to the card colour so it stays readable.
class CoutureFilterChip extends StatelessWidget {
  const CoutureFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final CoutureScheme c = CoutureScheme.of(context);
    final Color fg = selected ? c.card : c.inkList;
    return Material(
      color: selected ? c.iconInk : c.quiet,
      clipBehavior: Clip.antiAlias,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where an order is, in one pill. The glyph carries the meaning as much as
/// the word does — these shops have people who read slowly.
class CoutureStatusPill extends StatelessWidget {
  const CoutureStatusPill(
      {super.key, required this.status, this.compact = false});

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final CoutureScheme c = CoutureScheme.of(context);
    final (Color bg, Color fg, String label, IconData icon) = switch (status) {
      AppConstants.statusEnAttente => (
          c.quiet,
          c.inkSoft,
          'En attente',
          CoutureIcons.clock,
        ),
      AppConstants.statusEnCours => (
          c.iconWash,
          c.iconInk,
          'En couture',
          CoutureIcons.needle,
        ),
      AppConstants.statusTermine => (
          c.goodWash,
          c.goodInk,
          'Prêt',
          CoutureIcons.checkCircle,
        ),
      AppConstants.statusLivre => (
          c.quiet,
          c.inkSoft,
          'Livré',
          CoutureIcons.truck,
        ),
      AppConstants.statusAnnule => (
          c.urgentWash,
          c.urgentText,
          'Annulé',
          CoutureIcons.prohibit,
        ),
      _ => (c.quiet, c.inkSoft, status, CoutureIcons.warningCircle),
    };

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: compact ? 12 : 14, color: fg),
          SizedBox(width: compact ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nothing to show. Says what to do next rather than only that the list is
/// empty — an empty screen with no way forward is where people get stuck.
class CoutureEmpty extends StatelessWidget {
  const CoutureEmpty({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.tone = CoutureTone.normal,
  });

  final IconData icon;
  final String title;
  final String? message;
  final CoutureTone tone;

  @override
  Widget build(BuildContext context) {
    final CoutureScheme c = CoutureScheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CouturePalette.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CoutureWash(icon: icon, tone: tone, size: 72, iconSize: 32),
            const SizedBox(height: CouturePalette.s4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: c.ink,
              ),
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: CouturePalette.s2),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: c.inkSoft, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
