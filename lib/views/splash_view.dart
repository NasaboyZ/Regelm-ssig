import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: AppColors.backgroundColor,
    ),
    child: Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 402,
                height: 830,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(
                      top: 284,
                      child: ExcludeSemantics(
                        child: Image.asset(
                          'assets/screens/Logo.png',
                          width: 268,
                          height: 244,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 574,
                      left: 24,
                      right: 24,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Regelmässig',
                          style: AppTypography.splashScreen.copyWith(
                            color: const Color(0xFF1E1C1A),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 717,
                      child: Text(
                        'Privat. Lokal. Bei dir .',
                        style: AppTypography.body.copyWith(
                          color: const Color(0xFF1E1C1A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
