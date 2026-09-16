import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

/// Campus Innovate visual identity: academic crimson as the primary voice,
/// navy for structure, and a muted gold accent for highlights.
abstract final class AppTheme {
  static const Color crimson = Color(0xFF9E1B32);
  static const Color navy = Color(0xFF1F2A44);
  static const Color gold = Color(0xFFB08D3F);

  static const FlexSchemeColor _lightColors = FlexSchemeColor(
    primary: crimson,
    primaryContainer: Color(0xFFF7DDE1),
    secondary: navy,
    secondaryContainer: Color(0xFFDDE2EC),
    tertiary: gold,
    tertiaryContainer: Color(0xFFF6EAD2),
    appBarColor: crimson,
    error: Color(0xFFB3261E),
  );

  static const FlexSchemeColor _darkColors = FlexSchemeColor(
    primary: Color(0xFFE8909E),
    primaryContainer: Color(0xFF7A1426),
    secondary: Color(0xFFAFBDD8),
    secondaryContainer: Color(0xFF2C3A58),
    tertiary: Color(0xFFD9BC7C),
    tertiaryContainer: Color(0xFF6B5524),
    appBarColor: Color(0xFF2C3A58),
    error: Color(0xFFF2B8B5),
  );

  static const FlexSubThemesData _subThemes = FlexSubThemesData(
    interactionEffects: true,
    tintedDisabledControls: true,
    useM2StyleDividerInM3: true,
    defaultRadius: 14,
    cardRadius: 16,
    inputDecoratorIsFilled: true,
    inputDecoratorBorderType: FlexInputBorderType.outline,
    inputDecoratorRadius: 12,
    filledButtonRadius: 12,
    elevatedButtonRadius: 12,
    outlinedButtonRadius: 12,
    chipRadius: 10,
    alignedDropdown: true,
    navigationBarIndicatorSchemeColor: SchemeColor.primaryContainer,
    navigationBarSelectedIconSchemeColor: SchemeColor.primary,
    navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
    navigationRailUseIndicator: true,
  );

  static ThemeData light = FlexThemeData.light(
    colors: _lightColors,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 2,
    appBarStyle: FlexAppBarStyle.primary,
    appBarElevation: 0,
    subThemesData: _subThemes,
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
  );

  static ThemeData dark = FlexThemeData.dark(
    colors: _darkColors,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 8,
    appBarStyle: FlexAppBarStyle.background,
    appBarElevation: 0,
    subThemesData: _subThemes,
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
  );
}
