import 'package:flutter/material.dart';

/// Colors of the orange ribbon at the top (the same in light and dark themes).
/// The background keeps white text at a 4.5:1 contrast.
abstract final class RibbonColors {
  static const background = Color(0xFFBF4222);
  static const panel = Color(0xFFAD3A1D);
  static const panelBorder = Color(0xFFE08A6C);
  static const field = Color(0xFF96301A);
  static const selected = Color(0xFFD2573A);
  static const hover = Color(0x26FFFFFF);
  static const text = Color(0xFFFFFFFF);
  static const muted = Color(0xFFFBE0D5);
  static const divider = Color(0x40FFFFFF);
  static const menu = Color(0xFFB23C1F);
}

abstract final class RibbonText {
  static const label = TextStyle(color: RibbonColors.muted, fontSize: 11);
  static const control = TextStyle(color: RibbonColors.text, fontSize: 13);
  static const activeTab = TextStyle(
    color: RibbonColors.text,
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
  );
}

/// Theme of the menus opened from the ribbon.
MenuStyle ribbonMenuStyle() => const MenuStyle(
  backgroundColor: WidgetStatePropertyAll(RibbonColors.menu),
  surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
  ),
  padding: WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
  maximumSize: WidgetStatePropertyAll(Size(340, 600)),
);

ButtonStyle ribbonMenuItemStyle() => ButtonStyle(
  foregroundColor: const WidgetStatePropertyAll(RibbonColors.text),
  iconColor: const WidgetStatePropertyAll(RibbonColors.text),
  overlayColor: const WidgetStatePropertyAll(RibbonColors.hover),
  textStyle: const WidgetStatePropertyAll(RibbonText.control),
  padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
  minimumSize: const WidgetStatePropertyAll(Size(0, 38)),
  backgroundColor: WidgetStateProperty.resolveWith(
    (states) =>
        states.contains(WidgetState.disabled) ? null : Colors.transparent,
  ),
);
