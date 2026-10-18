import 'package:flutter/material.dart';

/// One onboarding slide.
///
/// Previously carried an `imagePath` pointing at `assets/images/onboarding{1,2,3}.png`.
/// Those files have never existed in this repository — `assets/images/` contained
/// only `.gitkeep` — so the field was dead weight that looked like a working asset
/// pipeline. The slides render an [icon] instead, which is what the UI actually did.
class OnboardingInfo {
  /// Material icon shown in the slide's illustration panel.
  final IconData icon;

  final String title;
  final String description;

  const OnboardingInfo({
    required this.icon,
    required this.title,
    required this.description,
  });
}