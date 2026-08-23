import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/couture_icons.dart';
import '../../../../core/theme/couture_palette.dart';
import '../../../../features/settings/presentation/providers/shop_settings_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// The home screen, redesigned onto "Indigo & Terre" (owner decision
/// 2026-08-23). This is the first screen to move; the rest follow one at a
/// time, which is why it reads `CouturePalette` and not `AppColors`.
///
/// What changed is the HIERARCHY, not the destinations. Before, fourteen
/// identical tiles meant "Vendre" — used dozens of times a day — carried
/// exactly the same weight as "Réglages", used once a month. Now:
///
///   1. the till, alone, in the band          — dozens of times a day
///   2. new order · find a client             — many times a day
///   3. the four of the day, as cards         — daily
///   4. the shop, as a quiet list             — weekly
///   5. management, as small chips            — monthly
///
/// Every route is the one it was. No API call, no computation, nothing
/// financial was touched: this file only decides what is drawn and how large.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final shop = context.watch<ShopSettingsProvider>();
    final bool isSec = auth.isSecretary;

    // The shop's own colour drives the band; indigo is only the default.
    final Color band = shop.themeColor;

    return Scaffold(
      backgroundColor: CoutureScheme.of(context).paper,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Two across on a phone; more only when there is real room.
            final int columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 620
                    ? 3
                    : 2;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    _Band(
                      band: band,
                      shopName: shop.shopName,
                      logoUrl: shop.logoUrl,
                      userName: auth.user?.name ?? '',
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          CouturePalette.s4 + 4, 18, CouturePalette.s4 + 4, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _quickPair(context),
                          const SizedBox(height: CouturePalette.s6 + 2),
                          const _SectionLabel('Le travail du jour'),
                          const SizedBox(height: CouturePalette.s3),
                          _dayGrid(context, columns),
                          const SizedBox(height: CouturePalette.s6 + 2),
                          const _SectionLabel('La boutique'),
                          const SizedBox(height: CouturePalette.s1),
                          _shopList(context, columns),
                          const SizedBox(height: CouturePalette.s6),
                          const _SectionLabel('Direction'),
                          const SizedBox(height: CouturePalette.s3),
                          _managementChips(context, isSec),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _quickPair(BuildContext context) => const Row(
        children: <Widget>[
          Expanded(
            child: _QuickCard(
              icon: CoutureIcons.plusCircle,
              label: 'Nouvelle\ncommande',
              route: '/admin/walk-in',
            ),
          ),
          SizedBox(width: CouturePalette.s3),
          Expanded(
            child: _QuickCard(
              icon: CoutureIcons.magnifyingGlass,
              label: 'Chercher\nun client',
              route: '/admin/customers',
            ),
          ),
        ],
      );

  Widget _dayGrid(BuildContext context, int columns) => GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        // A fixed HEIGHT, not an aspect ratio: an aspect ratio ties the card's
        // height to the phone's width, so the same card that breathes on a
        // 390-wide screen clipped its caption on a 320-wide one. The height is
        // what the contents need; only the width follows the screen.
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: CouturePalette.s3,
          mainAxisSpacing: CouturePalette.s3,
          mainAxisExtent: 118,
        ),
        children: const <Widget>[
          _DayCard(
            icon: CoutureIcons.clipboardText,
            title: 'Commandes',
            caption: 'Suivre et livrer',
            route: '/admin/orders',
          ),
          _DayCard(
            icon: CoutureIcons.scissors,
            title: 'Tailleurs',
            caption: 'Noter le travail',
            route: '/admin/staff',
          ),
          _DayCard(
            icon: CoutureIcons.images,
            title: 'Mon Album',
            caption: 'Montrer les modèles',
            route: '/admin/models-showcase',
          ),
          _DayCard(
            icon: CoutureIcons.calendarBlank,
            title: 'Rendez-vous',
            caption: 'Les dates promises',
            route: '/admin/appointments',
            urgent: true,
          ),
        ],
      );

  /// Weekly things: no card, no fill — a quiet list that reads as secondary.
  Widget _shopList(BuildContext context, int columns) {
    const List<Widget> items = <Widget>[
      _ShopRow(
          icon: CoutureIcons.shoppingBag,
          label: 'Produits',
          route: '/admin/products'),
      _ShopRow(
          icon: CoutureIcons.coatHanger,
          label: 'Prêt-à-porter',
          route: '/admin/ready-to-wear'),
      _ShopRow(
          icon: CoutureIcons.receipt,
          label: 'Les ventes',
          route: '/admin/sales-history'),
      _ShopRow(
          icon: CoutureIcons.clockCounterClockwise,
          label: 'Historique',
          route: '/admin/history'),
    ];

    final int perColumn = (items.length / columns).ceil();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int c = 0; c < columns; c++) ...<Widget>[
          if (c > 0) const SizedBox(width: CouturePalette.s6),
          Expanded(
            child: Column(
              children: items
                  .skip(c * perColumn)
                  .take(perColumn)
                  .toList(growable: false),
            ),
          ),
        ],
      ],
    );
  }

  /// Monthly things. Manager-only entries are simply not built for the
  /// secretary — the router and the API refuse them too (rule 1).
  Widget _managementChips(BuildContext context, bool isSec) => Wrap(
        spacing: CouturePalette.s2,
        runSpacing: CouturePalette.s2,
        children: <Widget>[
          if (!isSec)
            const _Chip(
                icon: CoutureIcons.wallet,
                label: 'Finances',
                route: '/admin/finance'),
          if (!isSec)
            const _Chip(
                icon: CoutureIcons.chartBar,
                label: 'Rapports',
                route: '/admin/reports'),
          if (!isSec)
            const _Chip(
                icon: CoutureIcons.storefront,
                label: 'Grossistes',
                route: '/admin/merchants'),
          const _Chip(
              icon: CoutureIcons.identificationBadge,
              label: 'Staff',
              route: '/admin/monthly-staff'),
          const _Chip(
              icon: CoutureIcons.gear,
              label: 'Réglages',
              route: '/admin/settings'),
        ],
      );
}

// =============================================================================
// The band: who the shop is, who is holding the phone, and the one action that
// happens dozens of times a day.
// =============================================================================
class _Band extends StatelessWidget {
  const _Band({
    required this.band,
    required this.shopName,
    required this.logoUrl,
    required this.userName,
  });

  final Color band;
  final String shopName;
  final String? logoUrl;
  final String userName;

  @override
  Widget build(BuildContext context) {
    // The band is the shop's OWN colour (`settings.theme_color`), and a shop is
    // free to pick a pale one. White on pale cream is unreadable, so the two
    // text tones follow the band rather than assuming indigo.
    final bool pale =
        ThemeData.estimateBrightnessForColor(band) == Brightness.light;
    final Color onBand = pale ? CouturePalette.ink : CouturePalette.onBand;
    final Color onBandSoft =
        pale ? CouturePalette.inkSoft : CouturePalette.onBandSoft;

    return Container(
      decoration: BoxDecoration(
        color: band,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(CouturePalette.s4 + 4,
          CouturePalette.s4, CouturePalette.s4 + 4, CouturePalette.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              _logo(pale: pale, onBand: onBand),
              const SizedBox(width: CouturePalette.s3),
              Expanded(
                child: Text(
                  shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'CormorantGaramond',
                    fontSize: 23,
                    fontWeight: FontWeight.w600,
                    color: onBand,
                    height: 1.1,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Se déconnecter',
                icon: Icon(CoutureIcons.signOut, size: 21, color: onBandSoft),
                onPressed: () => context.read<AuthProvider>().signOut(),
              ),
            ],
          ),
          const SizedBox(height: CouturePalette.s4),
          Text(_today(),
              style: CouturePalette.sectionLabel.copyWith(color: onBandSoft)),
          const SizedBox(height: CouturePalette.s1 + 1),
          Text(
            userName.isEmpty ? 'Bonjour' : 'Bonjour, $userName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: onBand,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 18),
          _SellButton(pale: pale),
        ],
      ),
    );
  }

  Widget _logo({required bool pale, required Color onBand}) {
    const double size = 38;
    final String? url = logoUrl;
    final Widget fallback = Center(
      child: Text(
        shopName.isNotEmpty ? shopName.characters.first.toUpperCase() : 'R',
        style: TextStyle(
          fontFamily: 'CormorantGaramond',
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: onBand,
          height: 1,
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (pale ? Colors.black : Colors.white).withValues(alpha: 0.08),
        border: Border.all(
            color: (pale ? Colors.black : Colors.white)
                .withValues(alpha: pale ? 0.16 : 0.22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: (url == null || url.isEmpty)
          ? fallback
          : CachedNetworkImage(
              imageUrl:
                  url.startsWith('http') ? url : '${ApiClient.baseUrl}$url',
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => fallback,
              placeholder: (_, __) => fallback,
            ),
    );
  }

  static String _today() {
    const List<String> days = <String>[
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche'
    ];
    const List<String> months = <String>[
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre'
    ];
    final DateTime n = DateTime.now();
    return '${days[n.weekday - 1]} ${n.day} ${months[n.month - 1]}';
  }
}

/// The till. The largest, warmest thing on the screen, because it is the thing
/// the shop does most.
class _SellButton extends StatelessWidget {
  const _SellButton({required this.pale});

  /// Whether the shop's band colour is a light one — then the cream chip needs
  /// an outline, or it dissolves into the band it sits on.
  final bool pale;

  @override
  Widget build(BuildContext context) {
    // Deliberately the light tokens in both themes: this is a cream chip on the
    // shop's own colour, and it should be the brightest thing on the screen at
    // midday on the street as much as at night.
    return Material(
      color: CouturePalette.paper,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: pale
            ? const BorderSide(color: CouturePalette.line)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => context.push('/admin/sell'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 15, 17, 15),
          child: Row(
            children: <Widget>[
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: CouturePalette.terracotta,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(CoutureIcons.cashRegister,
                    size: 27, color: Colors.white),
              ),
              const SizedBox(width: CouturePalette.s3 + 2),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('Vendre',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: CouturePalette.ink,
                            height: 1.15)),
                    SizedBox(height: 2),
                    Text('Encaisser un client',
                        style: TextStyle(
                            fontSize: 12.5, color: CouturePalette.inkSoft)),
                  ],
                ),
              ),
              const Icon(CoutureIcons.caretRight,
                  size: 18, color: CouturePalette.terracotta),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// The three weights below the band.
// =============================================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: CouturePalette.sectionLabel
            .copyWith(color: CoutureScheme.of(context).inkFaint),
      );
}

class _QuickCard extends StatelessWidget {
  const _QuickCard(
      {required this.icon, required this.label, required this.route});

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) => _Tappable(
        route: route,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: <Widget>[
              _Wash(icon: icon, size: 34, iconSize: 20),
              const SizedBox(width: 11),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: CoutureScheme.of(context).ink,
                        height: 1.25)),
              ),
            ],
          ),
        ),
      );
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.icon,
    required this.title,
    required this.caption,
    required this.route,
    this.urgent = false,
  });

  final IconData icon;
  final String title;
  final String caption;
  final String route;

  /// Rendez-vous is the one that carries a deadline, so it is the one allowed
  /// to use the warm colour. Keeping it scarce is what makes it mean anything.
  final bool urgent;

  @override
  Widget build(BuildContext context) => _Tappable(
        route: route,
        child: Padding(
          padding: const EdgeInsets.all(CouturePalette.s3 + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _Wash(icon: icon, urgent: urgent),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: CoutureScheme.of(context).ink)),
                  const SizedBox(height: 1),
                  Text(caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          color: CoutureScheme.of(context).inkFaint)),
                ],
              ),
            ],
          ),
        ),
      );
}

class _ShopRow extends StatelessWidget {
  const _ShopRow(
      {required this.icon, required this.label, required this.route});

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    final CoutureScheme c = CoutureScheme.of(context);
    return InkWell(
      onTap: () => context.push(route),
      child: Container(
        constraints: const BoxConstraints(minHeight: CouturePalette.minTouch),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.line)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: c.inkSoft),
            const SizedBox(width: 11),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, color: c.inkList)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.route});

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    final CoutureScheme c = CoutureScheme.of(context);
    return Material(
      color: c.quiet,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 15, color: c.inkSoft),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: c.inkList)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A white card with a warm hairline. Deliberately NOT a coloured left border:
/// a rounded card with an accent stripe down its left edge is the single most
/// recognisable tell of a generated interface.
class _Tappable extends StatelessWidget {
  const _Tappable({required this.route, required this.child});

  final String route;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
        color: CoutureScheme.of(context).card,
        clipBehavior: Clip.antiAlias,
        // `shape` and `borderRadius` are mutually exclusive on Material — the
        // rounded shape carries the radius so the hairline follows the corner.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: CoutureScheme.of(context).line),
        ),
        child: InkWell(onTap: () => context.push(route), child: child),
      );
}

/// The pale square an icon sits in.
class _Wash extends StatelessWidget {
  const _Wash({
    required this.icon,
    this.urgent = false,
    this.size = 40,
    this.iconSize = 22,
  });

  final IconData icon;
  final bool urgent;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final CoutureScheme c = CoutureScheme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: urgent ? c.urgentWash : c.iconWash,
        borderRadius: BorderRadius.circular(size >= 40 ? 11 : 10),
      ),
      child:
          Icon(icon, size: iconSize, color: urgent ? c.urgentInk : c.iconInk),
    );
  }
}
