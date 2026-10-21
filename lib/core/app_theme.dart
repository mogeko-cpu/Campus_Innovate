import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  /// The ground of every light screen: a whisper of the navy, so the white
  /// cards and panels on it read as a layer above it rather than as the same
  /// sheet of paper.
  static const Color paper = Color(0xFFF3F1F5);

  static ThemeData light = _withLayers(_withTypography(
    FlexThemeData.light(
      colors: _lightColors,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 2,
      appBarStyle: FlexAppBarStyle.primary,
      appBarElevation: 0,
      subThemesData: _subThemes,
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
    ),
  ));

  static ThemeData dark = _withLayers(_withTypography(
    FlexThemeData.dark(
      colors: _darkColors,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 8,
      appBarStyle: FlexAppBarStyle.background,
      appBarElevation: 0,
      subThemesData: _subThemes,
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
    ),
  ));

  /// Gives the screens their depth: a tinted ground, and everything that holds
  /// content — cards, dialogs, menus, the navigation bar — one layer above it,
  /// lighter, with a hairline edge and a soft shadow tinted with the navy
  /// instead of a grey one.
  ///
  /// The colors are the scheme's own; only where each surface sits changes. Out
  /// of the box Material draws a card a shade *darker* than the page, which is
  /// what left every screen looking flat.
  static ThemeData _withLayers(ThemeData base) {
    final colors = base.colorScheme;
    final dark = base.brightness == Brightness.dark;

    final raised =
        dark ? colors.surfaceContainer : colors.surfaceContainerLowest;
    final hairline =
        colors.outlineVariant.withValues(alpha: dark ? 0.35 : 0.55);
    final shadow =
        dark ? Colors.black.withValues(alpha: 0.55) : navy.withValues(alpha: 0.16);

    return base.copyWith(
      scaffoldBackgroundColor: dark ? base.scaffoldBackgroundColor : paper,
      cardTheme: base.cardTheme.copyWith(
        color: raised,
        surfaceTintColor: Colors.transparent,
        shadowColor: shadow,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: hairline),
        ),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: raised,
        surfaceTintColor: Colors.transparent,
        shadowColor: shadow,
        elevation: 10,
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 4,
        focusElevation: 6,
        hoverElevation: 6,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: raised,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: raised,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      // Fields sit on the panels like the cards sit on the page: lighter than
      // what holds them, with a soft edge that only turns crimson on focus.
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: raised,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colors.outlineVariant.withValues(alpha: dark ? 0.6 : 1),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(side: BorderSide(color: hairline)),
      dividerTheme: base.dividerTheme.copyWith(color: hairline),
      tabBarTheme: base.tabBarTheme.copyWith(
        labelStyle: base.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: base.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        dividerColor: hairline,
      ),
    );
  }

  /// Layers two Google Fonts onto FlexColorScheme's generated type scale:
  /// Sora for anything that reads as a heading, Inter for everything a person
  /// actually sits down and reads. FlexColorScheme's own `fontFamily` only
  /// takes one family for the whole theme, so the split happens here, after
  /// the base theme is built, by overriding just the display/headline/title
  /// styles and leaving body/label on the Inter baseline.
  static ThemeData _withTypography(ThemeData base) {
    final bodyTextTheme = GoogleFonts.interTextTheme(base.textTheme);
    final displayTextTheme = GoogleFonts.soraTextTheme(base.textTheme);

    final textTheme = bodyTextTheme.copyWith(
      displayLarge: displayTextTheme.displayLarge,
      displayMedium: displayTextTheme.displayMedium,
      displaySmall: displayTextTheme.displaySmall,
      headlineLarge: displayTextTheme.headlineLarge,
      headlineMedium: displayTextTheme.headlineMedium,
      headlineSmall: displayTextTheme.headlineSmall,
      titleLarge: displayTextTheme.titleLarge,
      titleMedium: displayTextTheme.titleMedium,
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: GoogleFonts.interTextTheme(base.primaryTextTheme),
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: displayTextTheme.titleLarge?.copyWith(
          color: base.appBarTheme.foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
