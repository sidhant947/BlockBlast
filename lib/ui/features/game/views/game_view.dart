import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blockblast/domain/models/game_level.dart';
import 'package:blockblast/domain/use_cases/block_blast_rules.dart';
import 'package:blockblast/ui/core/theme/app_colors.dart';
import 'package:blockblast/ui/core/widgets/tangible_button.dart';
import 'package:blockblast/ui/features/game/view_models/game_view_model.dart';
import 'package:blockblast/ui/providers.dart';
import 'package:url_launcher/url_launcher.dart';

class GameView extends ConsumerStatefulWidget {
  const GameView({
    super.key,
    required this.levelNumber,
    this.isRandom = false,
    this.randomDifficulty = 'Easy',
  });

  final int levelNumber;
  final bool isRandom;
  final String randomDifficulty;

  @override
  ConsumerState<GameView> createState() => _GameViewState();
}

class _GameViewState extends ConsumerState<GameView> {
  int? _selectedPieceIndex;
  int? _hoveredPieceIndex;
  int? _hoveredStartRow;
  int? _hoveredStartCol;

  final ShakeController _shakeController = ShakeController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (widget.isRandom) {
        ref.read(gameViewModelProvider.notifier).loadRandomLevel(widget.randomDifficulty);
      } else {
        ref.read(gameViewModelProvider.notifier).loadLevel(widget.levelNumber);
      }
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameViewModelProvider);

    ref.listen<GameViewModelState>(gameViewModelProvider, (prev, next) {
      if (next.isComplete && !(prev?.isComplete ?? false)) {
        _onLevelComplete(next);
      } else if (next.isGameOver && !(prev?.isGameOver ?? false)) {
        _onGameOver(next);
      } else if (next.lastClearedLines > 0 && next.lastClearedLines != (prev?.lastClearedLines ?? 0)) {
        HapticFeedback.heavyImpact();
        _shakeController.shake();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: ShakeWidget(
        controller: _shakeController,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _circleButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          iconSize: 18,
                          onTap: () => Navigator.pop(context),
                        ),
                        Text(
                          state.isRandomMode
                              ? 'RANDOM MODE'
                              : 'LEVEL ${widget.levelNumber}',
                          style: const TextStyle(
                            fontFamily: 'BebasNeue',
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.headingDark,
                            letterSpacing: 1.0,
                          ),
                        ),
                         Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _circleButton(
                              icon: Icons.refresh_rounded,
                              iconSize: 20,
                              onTap: () => ref
                                  .read(gameViewModelProvider.notifier)
                                  .resetLevel(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: state.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : state.error != null
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      state.error!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () => ref
                                          .read(gameViewModelProvider.notifier)
                                          .resetLevel(),
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            : _buildGame(state),
                  ),
                ],
              ),
              FloatingScoreOverlay(
                lastScore: state.lastMoveScore,
                combo: state.comboCount,
                clearedLines: state.lastClearedLines,
              ),
              ConfettiExplosion(trigger: state.isComplete),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGame(GameViewModelState state) {
    final level = state.level;
    if (level == null) return const SizedBox.shrink();

    final activePieceIndex = _hoveredPieceIndex ?? _selectedPieceIndex;
    final activePiece = activePieceIndex != null ? state.availablePieces[activePieceIndex] : null;
    final activeColorIndex = activePieceIndex != null ? state.pieceColors[activePieceIndex] : 0;
    final activeColor = AppColors.blockColors[activeColorIndex % AppColors.blockColors.length];

    bool isValidPlacement = false;
    final Set<String> previewCells = {};
    final Set<int> glowingRows = {};
    final Set<int> glowingCols = {};

    if (activePiece != null && _hoveredStartRow != null && _hoveredStartCol != null) {
      isValidPlacement = BlockBlastRules.canPlacePiece(
        state.board,
        activePiece,
        _hoveredStartRow!,
        _hoveredStartCol!,
      );
      for (int r = 0; r < activePiece.rows; r++) {
        for (int c = 0; c < activePiece.cols; c++) {
          if (activePiece.matrix[r][c] == 1) {
            final targetR = _hoveredStartRow! + r;
            final targetC = _hoveredStartCol! + c;
            if (targetR >= 0 && targetR < level.gridSize && targetC >= 0 && targetC < level.gridSize) {
              previewCells.add('$targetR,$targetC');
            }
          }
        }
      }

      if (isValidPlacement) {
        final simulatedBoard = List.generate(
          level.gridSize,
          (r) => List<int>.from(state.board[r]),
        );
        for (int r = 0; r < activePiece.rows; r++) {
          for (int c = 0; c < activePiece.cols; c++) {
            if (activePiece.matrix[r][c] == 1) {
              simulatedBoard[_hoveredStartRow! + r][_hoveredStartCol! + c] = 1;
            }
          }
        }
        glowingRows.addAll(BlockBlastRules.getCompletedRows(simulatedBoard));
        glowingCols.addAll(BlockBlastRules.getCompletedCols(simulatedBoard));
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white24,
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat('SCORE', '${state.score}', Icons.stars_rounded),
                  if (!state.isRandomMode) ...[
                    _verticalDivider(),
                    _stat('TARGET', '${level.targetScore}', Icons.flag_rounded),
                  ],
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12, width: 1.0),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: level.gridSize,
                          crossAxisSpacing: 3,
                          mainAxisSpacing: 3,
                        ),
                        itemCount: level.gridSize * level.gridSize,
                        itemBuilder: (context, index) {
                          final r = index ~/ level.gridSize;
                          final c = index % level.gridSize;
                          final cellVal = state.board[r][c];
                          final isPreviewCell = previewCells.contains('$r,$c');
                          final isLineGlowing = glowingRows.contains(r) || glowingCols.contains(c);

                          return DragTarget<int>(
                            onWillAcceptWithDetails: (details) {
                              setState(() {
                                _hoveredPieceIndex = details.data;
                                _hoveredStartRow = r;
                                _hoveredStartCol = c;
                              });
                              return true;
                            },
                            onLeave: (data) {
                              setState(() {
                                if (_hoveredStartRow == r && _hoveredStartCol == c) {
                                  _hoveredPieceIndex = null;
                                  _hoveredStartRow = null;
                                  _hoveredStartCol = null;
                                }
                              });
                            },
                            onAcceptWithDetails: (details) {
                              final pIdx = details.data;
                              ref
                                  .read(gameViewModelProvider.notifier)
                                  .placePiece(pIdx, r, c);
                              setState(() {
                                _selectedPieceIndex = null;
                                _hoveredPieceIndex = null;
                                _hoveredStartRow = null;
                                _hoveredStartCol = null;
                              });
                            },
                            builder: (context, candidateData, rejectedData) {
                              Widget cellWidget;

                              if (cellVal > 0) {
                                final color = AppColors.blockColors[(cellVal - 1) % AppColors.blockColors.length];
                                final isClearing = state.clearingRows.contains(r) || state.clearingCols.contains(c);
                                final isJustPlaced = state.isAnimating && !isClearing;

                                cellWidget = LayoutBuilder(
                                  builder: (context, box) {
                                    final block = _buildGlossyBlock(color, box.maxWidth, box.maxHeight);
                                    if (isClearing) {
                                      return TweenAnimationBuilder<double>(
                                        tween: Tween<double>(begin: 0.0, end: 1.0),
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeOutBack,
                                        builder: (context, value, child) {
                                          return Transform.rotate(
                                            angle: value * math.pi * 2,
                                            child: Transform.scale(
                                              scale: (1.0 - value).clamp(0.0, 1.0),
                                              child: Opacity(
                                                opacity: (1.0 - value).clamp(0.0, 1.0),
                                                child: child,
                                              ),
                                            ),
                                          );
                                        },
                                        child: block,
                                      );
                                    } else if (isJustPlaced) {
                                      return TweenAnimationBuilder<double>(
                                        tween: Tween<double>(begin: 1.0, end: 1.15),
                                        duration: const Duration(milliseconds: 75),
                                        curve: Curves.easeInOut,
                                        builder: (context, value, child) {
                                          return Transform.scale(
                                            scale: value,
                                            child: child,
                                          );
                                        },
                                        onEnd: () {
                                          // Reverse the pulse
                                          // Note: TweenAnimationBuilder is not ideal for bidirectional animations
                                          // but it serves for this simple pop effect.
                                        },
                                        child: block,
                                      );
                                    }
                                    return block;
                                  },
                                );
                              } else if (isPreviewCell) {
                                final isInvalid = !isValidPlacement;
                                return LayoutBuilder(
                                  builder: (context, box) {
                                    final block = _buildGlossyBlock(
                                      isInvalid ? Colors.red : activeColor,
                                      box.maxWidth,
                                      box.maxHeight,
                                      isPreview: true,
                                    );
                                    if (isInvalid) {
                                      return TweenAnimationBuilder<double>(
                                        tween: Tween<double>(begin: 0.2, end: 0.8),
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                        builder: (context, value, child) {
                                          return Opacity(
                                            opacity: value,
                                            child: child,
                                          );
                                        },
                                        child: block,
                                      );
                                    }
                                    return block;
                                  },
                                );
                              } else {
                                cellWidget = AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  decoration: BoxDecoration(
                                    color: isLineGlowing
                                        ? Colors.white.withValues(alpha: 0.18)
                                        : Colors.black26,
                                    borderRadius: BorderRadius.circular(4),
                                    border: isLineGlowing
                                        ? Border.all(color: Colors.white30, width: 1.0)
                                        : null,
                                  ),
                                );
                              }

                              return MouseRegion(
                                onEnter: (_) {
                                  if (_selectedPieceIndex != null) {
                                    setState(() {
                                      _hoveredStartRow = r;
                                      _hoveredStartCol = c;
                                    });
                                  }
                                },
                                onExit: (_) {
                                  if (_selectedPieceIndex != null && _hoveredStartRow == r && _hoveredStartCol == c) {
                                    setState(() {
                                      _hoveredStartRow = null;
                                      _hoveredStartCol = null;
                                    });
                                  }
                                },
                                child: InkWell(
                                  onTap: () {
                                    if (_selectedPieceIndex != null && cellVal == 0) {
                                      final placed = ref
                                          .read(gameViewModelProvider.notifier)
                                          .placePiece(_selectedPieceIndex!, r, c);
                                      if (placed) {
                                        setState(() {
                                          _selectedPieceIndex = null;
                                          _hoveredStartRow = null;
                                          _hoveredStartCol = null;
                                        });
                                      }
                                    }
                                  },
                                  child: cellWidget,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Container(
              height: math.min(constraints.maxHeight * 0.25, 140.0),
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (pIdx) {
                  final piece = state.availablePieces[pIdx];
                  if (piece == null) return const Expanded(child: SizedBox.shrink());

                  final colorIdx = state.pieceColors[pIdx];
                  final color = AppColors.blockColors[colorIdx % AppColors.blockColors.length];
                  final isSelected = _selectedPieceIndex == pIdx;

                  return Expanded(
                    child: LayoutBuilder(
                      builder: (context, pieceBox) {
                        final maxScaleW = (pieceBox.maxWidth - 20) / piece.cols - 2.0;
                        final maxScaleH = (pieceBox.maxHeight - 20) / piece.rows - 2.0;
                        final blockSize = math.max(8.0, math.min(24.0, math.min(maxScaleW, maxScaleH)));

                        return Center(
                          child: Draggable<int>(
                            data: pIdx,
                            dragAnchorStrategy: pointerDragAnchorStrategy,
                            feedback: const SizedBox.shrink(),
                            feedbackOffset: const Offset(0, -100),
                            childWhenDragging: Opacity(
                              opacity: 0.2,
                              child: _buildPiecePreview(piece, color, scale: blockSize),
                            ),
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _selectedPieceIndex = isSelected ? null : pIdx;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: isSelected
                                      ? Border.all(color: AppColors.primary, width: 2.0)
                                      : null,
                                ),
                                child: _buildPiecePreview(piece, color, scale: blockSize),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPiecePreview(BlockShape piece, Color color, {double scale = 18}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(piece.rows, (r) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(piece.cols, (c) {
            final fill = piece.matrix[r][c] == 1;
            if (!fill) {
              return SizedBox(width: scale + 2.0, height: scale + 2.0);
            }
            return Container(
              margin: const EdgeInsets.all(1.0),
              child: _buildGlossyBlock(color, scale, scale),
            );
          }),
        );
      }),
    );
  }

  Widget _buildGlossyBlock(Color color, double width, double height, {bool isPreview = false}) {
    final baseColor = isPreview ? color.withValues(alpha: 0.5) : color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3.0),
        boxShadow: isPreview
            ? [
                BoxShadow(
                  color: baseColor.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  offset: const Offset(0, 1.5),
                  blurRadius: 2.0,
                ),
              ],
      ),
      child: CustomPaint(
        painter: ChiseledBlockPainter(
          color: color,
          isPreview: isPreview,
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    double iconSize = 20,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.lightImpact();
              onTap();
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.35,
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
          child: Icon(
            icon,
            size: iconSize,
            color: AppColors.headingDark,
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColors.headingDark,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'BebasNeue',
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.headingDark,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'BebasNeue',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.subtext,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1.0,
      height: 30,
      color: AppColors.gridLines,
    );
  }

  Future<void> _onLevelComplete(GameViewModelState state) async {
    await ref.read(gameViewModelProvider.notifier).completeLevel();
    if (!mounted) return;
    _showCompleteDialog(state);
  }

  Future<void> _onGameOver(GameViewModelState state) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24, width: 1.0),
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.sentiment_dissatisfied_rounded,
                color: Color(0xFFEF4444),
                size: 56,
              ),
              const SizedBox(height: 20),
              const Text(
                'NO MORE MOVES!',
                style: TextStyle(
                  fontFamily: 'BebasNeue',
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.headingDark,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Final Score: ${state.score}',
                style: const TextStyle(
                  fontFamily: 'BebasNeue',
                  fontSize: 18,
                  color: AppColors.subtext,
                ),
              ),
              const SizedBox(height: 24),
              TangibleButton(
                text: 'Try Again',
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(gameViewModelProvider.notifier).resetLevel();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCompleteDialog(GameViewModelState state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white24,
              width: 1.0,
            ),
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white24,
                    width: 1.0,
                  ),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.primary,
                  size: 56,
                ),
              ),
              const SizedBox(height: 20),
              const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'LEVEL COMPLETE!',
                  style: TextStyle(
                    fontFamily: 'BebasNeue',
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.headingDark,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 220,
                child: Column(
                  children: [
                    TangibleButton(
                      text: state.isRandomMode ? 'Play Again' : 'Next Level',
                      height: 50,
                      onPressed: () {
                        Navigator.pop(context);
                        if (state.isRandomMode) {
                          ref
                              .read(gameViewModelProvider.notifier)
                              .loadRandomLevel(state.randomDifficulty ?? 'Easy');
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GameView(
                                levelNumber: widget.levelNumber + 1,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    TangibleButton(
                      text: 'Home',
                      isSecondary: true,
                      height: 50,
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 14),
                    TangibleButton(
                      text: 'Buy me a coffee',
                      isSecondary: true,
                      height: 50,
                      onPressed: () => launchUrl(
                        Uri.parse('https://buymeacoffee.com/sidhant947'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
  });

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy += 300.0 * dt;
  }
}

class ConfettiExplosion extends StatefulWidget {
  final bool trigger;
  const ConfettiExplosion({super.key, required this.trigger});

  @override
  State<ConfettiExplosion> createState() => _ConfettiExplosionState();
}

class _ConfettiExplosionState extends State<ConfettiExplosion>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<ConfettiParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addListener(_tick);
  }

  void _tick() {
    final dt = 0.016;
    for (final p in _particles) {
      p.update(dt);
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(ConfettiExplosion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _spawnParticles();
      _controller.forward(from: 0.0);
    }
  }

  void _spawnParticles() {
    _particles.clear();
    for (int i = 0; i < 60; i++) {
      _particles.add(
        ConfettiParticle(
          x: 200,
          y: 200,
          vx: (_random.nextDouble() - 0.5) * 400,
          vy: -_random.nextDouble() * 400 - 100,
          size: 6 + _random.nextDouble() * 6,
          color: AppColors.blockColors[_random.nextInt(AppColors.blockColors.length)],
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isAnimating) return const SizedBox.shrink();
    return CustomPaint(
      painter: _ConfettiPainter(_particles),
      child: const SizedBox.expand(),
    );
  }
}

class FloatingScoreOverlay extends StatefulWidget {
  final int lastScore;
  final int combo;
  final int clearedLines;

  const FloatingScoreOverlay({
    super.key,
    required this.lastScore,
    required this.combo,
    required this.clearedLines,
  });

  @override
  State<FloatingScoreOverlay> createState() => _FloatingScoreOverlayState();
}

class _FloatingScoreOverlayState extends State<FloatingScoreOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _translateY;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)),
    );

    _translateY = Tween<double>(begin: 0.0, end: -100.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.5, end: 1.4), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1.4, end: 1.0), weight: 70),
    ]).animate(_controller);

    if (widget.lastScore > 0) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(FloatingScoreOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lastScore > 0 && widget.lastScore != oldWidget.lastScore) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lastScore <= 0) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (!_controller.isAnimating && _controller.isCompleted) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: MediaQuery.of(context).size.height * 0.35 + _translateY.value,
          left: 0,
          right: 0,
          child: Center(
            child: Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '+${widget.lastScore}',
                      style: const TextStyle(
                        fontFamily: 'BebasNeue',
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4)),
                        ],
                      ),
                    ),
                    if (widget.combo > 1)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9F1C),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
                          ],
                        ),
                        child: Text(
                          'COMBO x${widget.combo}!',
                          style: const TextStyle(
                            fontFamily: 'BebasNeue',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;

  _ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()..color = p.color;
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}

class ChiseledBlockPainter extends CustomPainter {
  final Color color;
  final bool isPreview;

  ChiseledBlockPainter({
    required this.color,
    required this.isPreview,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final baseColor = isPreview ? color.withValues(alpha: 0.5) : color;

    final paint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;

    final rect = Rect.fromLTWH(0, 0, w, h);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3.0));
    canvas.drawRRect(rrect, paint);

    canvas.save();
    canvas.clipRRect(rrect);

    final bevel = w * 0.16;
    final hsl = HSLColor.fromColor(baseColor);

    final topHighlight = hsl.withLightness(math.min(1.0, hsl.lightness + 0.28)).toColor();
    final topHighlightEnd = hsl.withLightness(math.min(1.0, hsl.lightness + 0.12)).toColor();

    final leftHighlight = hsl.withLightness(math.min(1.0, hsl.lightness + 0.18)).toColor();
    final leftHighlightEnd = hsl.withLightness(math.min(1.0, hsl.lightness + 0.05)).toColor();

    final bottomShadow = hsl.withLightness(math.max(0.0, hsl.lightness - 0.18)).toColor();
    final bottomShadowEnd = hsl.withLightness(math.max(0.0, hsl.lightness - 0.28)).toColor();

    final rightShadow = hsl.withLightness(math.max(0.0, hsl.lightness - 0.22)).toColor();
    final rightShadowEnd = hsl.withLightness(math.max(0.0, hsl.lightness - 0.32)).toColor();

    final topPath = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w - bevel, bevel)
      ..lineTo(bevel, bevel)
      ..close();

    final topPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          topHighlight.withValues(alpha: isPreview ? 0.4 : 0.8),
          topHighlightEnd.withValues(alpha: isPreview ? 0.3 : 0.6)
        ],
      ).createShader(Rect.fromLTRB(0, 0, w, bevel))
      ..style = PaintingStyle.fill;
    canvas.drawPath(topPath, topPaint);

    final leftPath = Path()
      ..moveTo(0, 0)
      ..lineTo(bevel, bevel)
      ..lineTo(bevel, h - bevel)
      ..lineTo(0, h)
      ..close();

    final leftPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          leftHighlight.withValues(alpha: isPreview ? 0.3 : 0.7),
          leftHighlightEnd.withValues(alpha: isPreview ? 0.2 : 0.5)
        ],
      ).createShader(Rect.fromLTRB(0, 0, bevel, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(leftPath, leftPaint);

    final bottomPath = Path()
      ..moveTo(bevel, h - bevel)
      ..lineTo(w - bevel, h - bevel)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final bottomPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          bottomShadowEnd.withValues(alpha: isPreview ? 0.3 : 0.6),
          bottomShadow.withValues(alpha: isPreview ? 0.4 : 0.8)
        ],
      ).createShader(Rect.fromLTRB(0, h - bevel, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(bottomPath, bottomPaint);

    final rightPath = Path()
      ..moveTo(w - bevel, bevel)
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(w - bevel, h - bevel)
      ..close();

    final rightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          rightShadowEnd.withValues(alpha: isPreview ? 0.2 : 0.5),
          rightShadow.withValues(alpha: isPreview ? 0.3 : 0.7)
        ],
      ).createShader(Rect.fromLTRB(w - bevel, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(rightPath, rightPaint);

    canvas.restore();

    final outerStrokePaint = Paint()
      ..color = Colors.black.withValues(alpha: isPreview ? 0.2 : 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(rrect, outerStrokePaint);

    final innerRect = Rect.fromLTRB(bevel, bevel, w - bevel, h - bevel);
    final innerStrokePaint = Paint()
      ..color = Colors.black.withValues(alpha: isPreview ? 0.08 : 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawRect(innerRect, innerStrokePaint);
  }

  @override
  bool shouldRepaint(covariant ChiseledBlockPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isPreview != isPreview;
  }
}

class ShakeController {
  AnimationController? _controller;

  void setController(AnimationController controller) {
    _controller = controller;
  }

  void shake() {
    _controller?.forward(from: 0.0);
  }

  void dispose() {
    _controller?.dispose();
  }
}

class ShakeWidget extends StatefulWidget {
  final ShakeController controller;
  final Widget child;

  const ShakeWidget({super.key, required this.controller, required this.child});

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    widget.controller.setController(_animationController);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final shake = math.sin(_animation.value * math.pi * 4) * 8.0 * (1 - _animation.value);
        return Transform.translate(
          offset: Offset(shake, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
