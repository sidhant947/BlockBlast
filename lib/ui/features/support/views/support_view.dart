import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:blockblast/ui/core/theme/app_colors.dart';
import 'package:blockblast/ui/core/widgets/tangible_button.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportView extends StatelessWidget {
  const SupportView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white24,
                                    width: 1.0,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 18,
                                  color: AppColors.headingDark,
                                ),
                              ),
                            ),
                            const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'SUPPORT US',
                                style: TextStyle(
                                  color: AppColors.headingDark,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 42),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white24,
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.favorite_rounded,
                                color: Color(0xFFEF4444),
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'ENJOYING BLOCK BLAST?',
                                  style: TextStyle(
                                    color: AppColors.headingDark,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'This game is 100% free and open-source! If you love playing it, consider supporting future development.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.subtext,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 24),
                              TangibleButton(
                                text: 'Buy Me a Coffee ☕',
                                onPressed: () => launchUrl(
                                  Uri.parse('https://ko-fi.com/sidhant947'),
                                  mode: LaunchMode.externalApplication,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
