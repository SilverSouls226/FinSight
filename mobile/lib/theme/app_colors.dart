import 'package:flutter/material.dart';

/// FinSentinel is a financial *control system*, not a banking clone —
/// dark, instrument-panel palette with a green/amber/red risk language
/// used consistently across Financial Weather, the Digital Twin, and
/// Intervention severities.
class AppColors {
  const AppColors._();

  static const background = Color(0xFF0B0E14);
  static const surface = Color(0xFF141822);
  static const surfaceRaised = Color(0xFF1B2130);
  static const border = Color(0xFF2A3142);

  static const textPrimary = Color(0xFFF2F4F8);
  static const textSecondary = Color(0xFFA0A8BA);
  static const textMuted = Color(0xFF6B7385);

  static const accent = Color(0xFF5B8CFF);
  static const accentSoft = Color(0xFF223258);

  static const stable = Color(0xFF35D68A);
  static const stableSoft = Color(0xFF16332A);

  static const pressure = Color(0xFFF5B942);
  static const pressureSoft = Color(0xFF3A3018);

  static const storm = Color(0xFFFF5C6C);
  static const stormSoft = Color(0xFF3A1A20);

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
