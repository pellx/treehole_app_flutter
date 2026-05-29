import 'package:flutter/material.dart';

class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color secondary;
  final Color borderColor;
  final Color authorColor;
  final Color accentText;
  final Color buttonBg;
  final Color green;
  final Color attachment;

  const AppColors({
    required this.background,
    required this.secondary,
    required this.borderColor,
    required this.authorColor,
    required this.accentText,
    required this.buttonBg,
    required this.green,
    required this.attachment,
  });

  static const light = AppColors(
    background: Color(0xFFFFFFFF),
    secondary: Color(0xFF747474),
    borderColor: Color(0xFF999999),
    authorColor: Color(0xFF2F68C5),
    accentText: Color(0xFF33B1FF),
    buttonBg: Color(0xFF2CAEFF),
    green: Color(0xFF7BB380),
    attachment: Color(0xFF545FFF),
  );

  static const dark = AppColors(
    background: Color(0xFF121212),
    secondary: Color(0x70999999),
    borderColor: Color(0xFF444444),
    authorColor: Color(0xFF2F68C5),
    accentText: Color(0xBA5498FF),
    buttonBg: Color(0xFF2693FF),
    green: Color(0xFF7BB380),
    attachment: Color(0xFF616BFF),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? secondary,
    Color? borderColor,
    Color? authorColor,
    Color? accentText,
    Color? buttonBg,
    Color? green,
    Color? attachment,
  }) {
    return AppColors(
      background: background ?? this.background,
      secondary: secondary ?? this.secondary,
      borderColor: borderColor ?? this.borderColor,
      authorColor: authorColor ?? this.authorColor,
      accentText: accentText ?? this.accentText,
      buttonBg: buttonBg ?? this.buttonBg,
      green: green ?? this.green,
      attachment: attachment ?? this.attachment,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      authorColor: Color.lerp(authorColor, other.authorColor, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      buttonBg: Color.lerp(buttonBg, other.buttonBg, t)!,
      green: Color.lerp(green, other.green, t)!,
      attachment: Color.lerp(attachment, other.attachment, t)!,
    );
  }
}
