import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blockblast/ui/core/theme/app_colors.dart';
import 'package:blockblast/ui/features/game/views/game_view.dart';
import 'package:blockblast/ui/providers.dart';

class LevelSelectView extends ConsumerWidget {
  const LevelSelectView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeViewModelProvider);
    final unlocked = homeState.progress?.unlockedLevels ?? 1;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
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
                    'LEVELS',
                    style: TextStyle(
                      fontFamily: 'BebasNeue',
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.headingDark,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(width: 42),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: 60,
                  itemBuilder: (context, index) {
                    final levelNum = index + 1;
                    final isCompleted = levelNum < unlocked;
                    final isCurrent = levelNum == unlocked;
                    final isUnlocked = levelNum <= unlocked;

                    return GestureDetector(
                      onTap: isUnlocked
                          ? () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => GameView(levelNumber: levelNum),
                                ),
                              );
                            }
                          : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? const Color(0xFF2E7D32).withValues(alpha: 0.15)
                              : (isCurrent
                                  ? const Color(0xFFEF6C00).withValues(alpha: 0.15)
                                  : AppColors.bg),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCompleted
                                ? const Color(0xFF4CAF50)
                                : (isCurrent
                                    ? const Color(0xFFFF9800)
                                    : Colors.white12),
                            width: isUnlocked ? 2.0 : 1.0,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: isUnlocked
                            ? Text(
                                '$levelNum',
                                style: TextStyle(
                                  fontFamily: 'BebasNeue',
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted
                                      ? const Color(0xFF81C784)
                                      : (isCurrent
                                          ? const Color(0xFFFFB74D)
                                          : AppColors.headingDark),
                                ),
                              )
                            : const Icon(
                                Icons.lock_rounded,
                                size: 20,
                                color: Colors.white24,
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
