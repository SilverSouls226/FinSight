import 'package:flutter/material.dart';

/// FinSentinel — light, "calm fintech" layout (GPay / Revolut / Monzo
/// language: white cards, soft shadows) with an earthy sage/dark-green/
/// gold accent palette, and a green/amber/red risk language used
/// consistently across Financial Weather, the Digital Twin, and
/// Intervention severities.
class AppColors {
  const AppColors._();

  static const page = Color(0xFFE9ECF4);
  static const background = Color(0xFFF6F7FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceRaised = Color(0xFFF7F9FC);
  static const border = Color(0xFFEEF1F6);

  static const textPrimary = Color(0xFF0F1626);
  static const textSecondary = Color(0xFF5A6478);
  static const textMuted = Color(0xFF95A0B5);

  static const accent = Color(0xFF0C3B2E); // dark green
  static const accent2 = Color(0xFF6D9773); // sage green
  static const accentSoft = Color(0xFFE8EFEA);
  static const blue = Color(0xFFBB8A52); // tan (kept for API compat; unused in current UI)

  static const stable = Color(0xFF12B76A);
  static const stableSoft = Color(0xFFE7F8EF);

  static const pressure = Color(0xFFFFBA00); // gold
  static const pressureSoft = Color(0xFFFFF6DF);

  static const storm = Color(0xFFF04438);
  static const stormSoft = Color(0xFFFDECEB);

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accent2],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accent2],
  );

  static Color severityColor(String severity) {
    switch (severity) {
      case 'high':
        return storm;
      case 'medium':
        return pressure;
      default:
        return stable;
    }
  }

  static Color severitySoftColor(String severity) {
    switch (severity) {
      case 'high':
        return stormSoft;
      case 'medium':
        return pressureSoft;
      default:
        return stableSoft;
    }
  }
}
