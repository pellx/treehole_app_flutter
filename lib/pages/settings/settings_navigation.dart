import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';

void navigateToSubPage(BuildContext context, String title, Widget body) {
  Navigator.of(context).push(MaterialPageRoute(builder: (ctx) {
    return Builder(builder: (scaffoldCtx) {
      final colors = Theme.of(scaffoldCtx).extension<AppColors>()!;
      final barText = colors.common.barText;
      return Scaffold(
        backgroundColor: Theme.of(scaffoldCtx).scaffoldBackgroundColor,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                height: AppDimens.settingsBarHeight,
                color: colors.common.drawerHeaderBg,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: barText),
                      onPressed: () => Navigator.pop(scaffoldCtx),
                    ),
                    Expanded(
                      child: Text(title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: barText)),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      );
    });
  }));
}

Route<T> topDownRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
      child: child,
    ),
    transitionDuration: Duration(milliseconds: AppDimens.drawerAnimMs),
  );
}

void navigateToSettingsPage(BuildContext context, String title, Widget body) {
  Navigator.of(context).push(PageRouteBuilder(
    pageBuilder: (_, __, ___) {
      return Builder(builder: (scaffoldCtx) {
        final colors = Theme.of(scaffoldCtx).extension<AppColors>()!;
        final barText = colors.common.barText;
        return Scaffold(
          backgroundColor: Theme.of(scaffoldCtx).scaffoldBackgroundColor,
          body: Column(
            children: [
              Container(
                color: colors.common.drawerHeaderBg,
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: AppDimens.settingsBarHeight,
                    child: Row(
                      children: [
                        IconButton(
                          icon:
                              Icon(Icons.keyboard_arrow_up, color: barText),
                          onPressed: () => Navigator.pop(scaffoldCtx),
                        ),
                        Expanded(
                          child: Text(title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                  color: barText)),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(child: body),
            ],
          ),
        );
      });
    },
    transitionsBuilder: (_, animation, __, child) => SlideTransition(
      position:
          Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut)),
      child: child,
    ),
    transitionDuration: Duration(milliseconds: AppDimens.drawerAnimMs),
  ));
}
