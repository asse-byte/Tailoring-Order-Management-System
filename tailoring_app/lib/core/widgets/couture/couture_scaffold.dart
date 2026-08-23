import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../theme/couture_icons.dart';
import '../../theme/couture_palette.dart';
import '../../../features/settings/presentation/providers/shop_settings_provider.dart';

/// The frame every redesigned screen sits in.
///
/// It exists so the screens migrating to "Indigo & Terre" one at a time do not
/// each invent their own header. The band is the shop's own
/// `settings.theme_color` — the same band as the home screen, thinner — so a
/// screen reads as part of the same shop rather than a Material default with a
/// title in it.
///
/// It is a NEW widget rather than a change to `Scaffold`/`AppBar` styling on
/// purpose: nothing here touches a screen that has not been redesigned yet.
class CoutureScaffold extends StatelessWidget {
  const CoutureScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const <Widget>[],
    this.below,
    this.floatingActionButton,
    this.onBack,
  });

  final String title;

  /// One short line under the title. Use it for what the screen is FOR, in
  /// words the secretary would say out loud — not a count or a status.
  final String? subtitle;

  /// Icon buttons on the band. Build them with [CoutureBandAction] so they
  /// get the right tone against the shop's colour.
  final List<Widget> actions;

  /// Anything that belongs to the header but is not the band: a search field,
  /// a row of filters. It sits on the paper, directly under the band.
  final Widget? below;

  final Widget child;
  final Widget? floatingActionButton;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final CoutureScheme c = CoutureScheme.of(context);
    final Color band = context.watch<ShopSettingsProvider>().themeColor;
    final bool pale =
        ThemeData.estimateBrightnessForColor(band) == Brightness.light;
    final Color onBand = pale ? CouturePalette.ink : CouturePalette.onBand;
    final Color onBandSoft =
        pale ? CouturePalette.inkSoft : CouturePalette.onBandSoft;

    return Scaffold(
      backgroundColor: c.paper,
      floatingActionButton: floatingActionButton,
      body: Column(
        children: <Widget>[
          Container(
            color: band,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(CouturePalette.s2,
                    CouturePalette.s2, CouturePalette.s2, 14),
                child: Row(
                  children: <Widget>[
                    _BackButton(tone: onBand, onBack: onBack),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: onBand,
                              height: 1.15,
                            ),
                          ),
                          if (subtitle != null) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: onBandSoft),
                            ),
                          ],
                        ],
                      ),
                    ),
                    for (final Widget a in actions)
                      _BandActionTone(tone: onBandSoft, child: a),
                  ],
                ),
              ),
            ),
          ),
          if (below != null) below!,
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tone, this.onBack});

  final Color tone;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Retour',
        icon: Icon(CoutureIcons.caretLeft, size: 22, color: tone),
        onPressed: onBack ??
            () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/admin');
              }
            },
      );
}

/// Passes the band's text tone down to the actions, so a screen writes
/// `CoutureBandAction(icon: …, tooltip: …, onPressed: …)` and never has to know
/// whether this shop's colour is dark or pale.
class _BandActionTone extends InheritedWidget {
  const _BandActionTone({required this.tone, required super.child});

  final Color tone;

  static Color of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BandActionTone>()?.tone ??
      CouturePalette.onBandSoft;

  @override
  bool updateShouldNotify(_BandActionTone old) => old.tone != tone;
}

class CoutureBandAction extends StatelessWidget {
  const CoutureBandAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: 20, color: _BandActionTone.of(context)),
        onPressed: onPressed,
      );
}
