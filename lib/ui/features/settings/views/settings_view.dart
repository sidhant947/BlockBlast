import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:blockblast/ui/core/theme/app_colors.dart';
import 'package:blockblast/ui/providers.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(
        uri,
        mode: uri.isScheme('mailto')
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 26,
                  color: AppColors.headingDark,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.headingDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.open_in_new_rounded,
                  size: 20,
                  color: AppColors.subtext,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundEnabled = ref.watch(soundSettingsProvider);
    final compactLayoutEnabled = ref.watch(compactLayoutSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                        border: Border.all(color: Colors.white24, width: 1.0),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: AppColors.headingDark,
                      ),
                    ),
                  ),
                  const Text(
                    'SETTINGS',
                    style: TextStyle(
                      color: AppColors.headingDark,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 42),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24, width: 1.0),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(soundSettingsProvider.notifier).toggle();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            soundEnabled
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            size: 26,
                            color: soundEnabled
                                ? AppColors.headingDark
                                : AppColors.subtext,
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sound Effects',
                                  style: TextStyle(
                                    color: AppColors.headingDark,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: soundEnabled,
                            activeTrackColor: const Color(0xFF34C759),
                            onChanged: (val) {
                              HapticFeedback.lightImpact();
                              ref
                                  .read(soundSettingsProvider.notifier)
                                  .setSoundEnabled(val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24, width: 1.0),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(compactLayoutSettingsProvider.notifier).toggle();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            compactLayoutEnabled
                                ? Icons.grid_view_rounded
                                : Icons.grid_view_outlined,
                            size: 26,
                            color: compactLayoutEnabled
                                ? AppColors.headingDark
                                : AppColors.subtext,
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Top-Aligned Layout',
                                  style: TextStyle(
                                    color: AppColors.headingDark,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Grid attaches to goals with centered pieces',
                                  style: TextStyle(
                                    color: AppColors.subtext,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: compactLayoutEnabled,
                            activeTrackColor: const Color(0xFF34C759),
                            onChanged: (val) {
                              HapticFeedback.lightImpact();
                              ref
                                  .read(compactLayoutSettingsProvider.notifier)
                                  .setLayoutEnabled(val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _actionCard(
                icon: Icons.favorite_rounded,
                title: 'Become a Backer',
                onTap: () => _openUrl('https://ko-fi.com/sidhant947/tiers'),
              ),
              const SizedBox(height: 16),
              _actionCard(
                icon: Icons.alternate_email_rounded,
                title: 'Follow on Mastodon',
                onTap: () => _openUrl('https://mastodon.social/@sidhant947'),
              ),
              const SizedBox(height: 16),
              _actionCard(
                icon: Icons.mail_outline_rounded,
                title: 'Contact Email',
                onTap: () => _openUrl('mailto:sidhant947@proton.me'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
