import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';

class _Slide {
  const _Slide(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefsKeyOnboardingDone, true);
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final List<_Slide> slides = <_Slide>[
      _Slide(
        Icons.checkroom_outlined,
        context.loc.onbTitle1,
        context.loc.onbDesc1,
      ),
      _Slide(
        Icons.timeline_outlined,
        context.loc.onbTitle2,
        context.loc.onbDesc2,
      ),
      _Slide(
        Icons.notifications_active_outlined,
        context.loc.onbTitle3,
        context.loc.onbDesc3,
      ),
    ];

    final bool isLast = _index == slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(context.loc.skip),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: slides.length,
                itemBuilder: (_, i) {
                  final s = slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          height: 140,
                          width: 140,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child:
                              Icon(s.icon, size: 64, color: AppColors.primary),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          s.body,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(
                slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: i == _index ? 28 : 8,
                  decoration: BoxDecoration(
                    color: i == _index ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: <Widget>[
                  PrimaryButton(
                    label: isLast ? context.loc.getStarted : context.loc.next,
                    onPressed: () {
                      if (isLast) {
                        _finish();
                      } else {
                        _pageCtrl.nextPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  if (!isLast)
                    SecondaryButton(
                      label: context.loc.alreadyHaveAccountOnb,
                      onPressed: _finish,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
