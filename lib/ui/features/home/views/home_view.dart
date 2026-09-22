import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:blockblast/ui/core/theme/app_colors.dart';
import 'package:blockblast/ui/core/widgets/tangible_button.dart';
import 'package:blockblast/ui/features/game/views/game_view.dart';
import 'package:blockblast/ui/features/level_select/views/level_select_view.dart';
import 'package:blockblast/ui/features/support/views/support_view.dart';
import 'package:blockblast/ui/providers.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(homeViewModelProvider.notifier).loadProgress(),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    double iconSize = 20,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1.0),
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: iconColor ?? AppColors.headingDark,
        ),
      ),
    );
  }

  void _showGridSizeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24, width: 1.0),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Choose a grid size',
                style: TextStyle(
                  color: AppColors.subtext,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              for (final size in [6, 8, 10]) ...[
                TangibleButton(
                  text: '$size x $size',
                  isSecondary: size != 8,
                  height: 48,
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GameView(
                          levelNumber: 0,
                          isRandom: true,
                          randomDifficulty: 'Endless',
                          gridSize: size,
                        ),
                      ),
                    );
                  },
                ),
                if (size != 10) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeViewModelProvider);

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
                            _circleButton(
                              icon: Icons.star_rounded,
                              iconColor: const Color(0xFFFFCC00),
                              onTap: () => _launchUrl(
                                'https://github.com/sidhant947/BlockBlast',
                              ),
                            ),
                            if (state.progress != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white24,
                                    width: 1.0,
                                  ),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'LEVEL ${state.progress!.currentLevel}',
                                    style: const TextStyle(
                                      color: AppColors.headingDark,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              )
                            else
                              const SizedBox.shrink(),
                            _circleButton(
                              icon: Icons.favorite_rounded,
                              iconColor: const Color(0xFFEF4444),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SupportView(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(flex: 3),

                        const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'BLOCK BLAST',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'A TACTILE BLOCK PUZZLE ADVENTURE',
                            style: TextStyle(
                              color: AppColors.subtext,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),

                        const Spacer(flex: 4),

                        TangibleButton(
                          text:
                              state.progress == null ||
                                  state.progress!.currentLevel <= 1
                              ? 'Start Game'
                              : 'Play',
                          onPressed: state.isLoading
                              ? null
                              : () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => GameView(
                                        levelNumber:
                                            state.progress?.currentLevel ?? 1,
                                      ),
                                    ),
                                  );
                                  ref
                                      .read(homeViewModelProvider.notifier)
                                      .loadProgress();
                                },
                        ),

                        const SizedBox(height: 16),

                        TangibleButton(
                          text: 'Levels',
                          isSecondary: true,
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LevelSelectView(),
                              ),
                            );
                            ref
                                .read(homeViewModelProvider.notifier)
                                .loadProgress();
                          },
                        ),

                        const SizedBox(height: 16),

                        TangibleButton(
                          text: 'Endless Mode',
                          isSecondary: true,
                          onPressed: () => _showGridSizeDialog(context),
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
