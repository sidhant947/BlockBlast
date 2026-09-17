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

class _GameViewState extends ConsumerState<GameView>
    with TickerProviderStateMixin {
  int? _selectedPieceIndex;
  int? _hoveredPieceIndex;
  int? _hoveredStartRow;
  int? _hoveredStartCol;

  final ShakeController _shakeController = ShakeController();
  final GlobalKey<_ShatterParticleOverlayState> _shatterKey = GlobalKey();
  final GlobalKey<_ComboCalloutOverlayState> _calloutKey = GlobalKey();
  final GlobalKey _boardKey = GlobalKey();

  void _updateDragHover(
    int pIdx,
    Offset globalPosition,
    BlockShape piece,
    int gridSize,
  ) {
    final RenderBox? boardBox =
        _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (boardBox == null || !boardBox.hasSize) return;

    final Offset localPos = boardBox.globalToLocal(globalPosition);
    const double padding = 8.0;
    final double gridWidth = boardBox.size.width - (padding * 2);
    final double cellSize = gridWidth / gridSize;

    const double fingerOffset = 75.0;
    final double targetY = localPos.dy - padding - fingerOffset;
    final double targetX = localPos.dx - padding;

    final int c = ((targetX - (piece.cols * cellSize / 2)) / cellSize).round();
    final int r = ((targetY - (piece.rows * cellSize)) / cellSize).round();

    if (r >= 0 &&
        r <= gridSize - piece.rows &&
        c >= 0 &&
        c <= gridSize - piece.cols) {
      if (_hoveredStartRow != r ||
          _hoveredStartCol != c ||
          _hoveredPieceIndex != pIdx) {
        HapticFeedback.selectionClick();
        setState(() {
          _hoveredPieceIndex = pIdx;
          _hoveredStartRow = r;
          _hoveredStartCol = c;
        });
      }
    } else {
      if (_hoveredStartRow != null || _hoveredStartCol != null) {
        setState(() {
          _hoveredPieceIndex = null;
          _hoveredStartRow = null;
          _hoveredStartCol = null;
        });
      }
    }
  }

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    Future.microtask(() {
      if (widget.isRandom) {
        ref
            .read(gameViewModelProvider.notifier)
            .loadRandomLevel(widget.randomDifficulty);
      } else {
        ref.read(gameViewModelProvider.notifier).loadLevel(widget.levelNumber);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
      } else if (next.lastClearedLines > 0 &&
          next.lastClearedLines != (prev?.lastClearedLines ?? 0)) {
        HapticFeedback.heavyImpact();
        _shakeController.shake();
        _shatterKey.currentState?.triggerShatter(
          clearingRows: next.clearingRows,
          clearingCols: next.clearingCols,
          board: prev?.board ?? next.board,
        );
        _calloutKey.currentState?.triggerCallout(
          clearedLines: next.lastClearedLines,
          combo: next.comboCount,
        );
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _circleButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          iconSize: 18,
                          onTap: () => Navigator.pop(context),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            state.isRandomMode
                                ? 'RANDOM MODE'
                                : 'LEVEL ${widget.levelNumber}',
                            style: const TextStyle(
                              color: AppColors.headingDark,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
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
                                  style: const TextStyle(color: Colors.red),
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
              ComboCalloutOverlay(key: _calloutKey),
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
    final activePiece = activePieceIndex != null
        ? state.availablePieces[activePieceIndex]
        : null;
    final activeColorIndex = activePieceIndex != null
        ? state.pieceColors[activePieceIndex]
        : 0;
    final activeColor =
        AppColors.blockColors[activeColorIndex % AppColors.blockColors.length];

    bool isValidPlacement = false;
    final Set<String> previewCells = {};
    final Set<int> glowingRows = {};
    final Set<int> glowingCols = {};

    if (activePiece != null &&
        _hoveredStartRow != null &&
        _hoveredStartCol != null) {
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
            if (targetR >= 0 &&
                targetR < level.gridSize &&
                targetC >= 0 &&
                targetC < level.gridSize) {
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
                border: Border.all(color: Colors.white24, width: 1.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _animatedStat('SCORE', state.score, Icons.stars_rounded),
                  if (!state.isRandomMode) ...[
                    _verticalDivider(),
                    _stat('TARGET', '${level.targetScore}', Icons.flag_rounded),
                    if (level.targetFrozen > 0 || level.targetGems > 0) ...[
                      _verticalDivider(),
                      _objectiveStat(
                        'GOALS',
                        frozen: state.remainingFrozen,
                        gems: state.remainingGems,
                      ),
                    ],
                  ],
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Stack(
                      children: [
                        Container(
                          key: _boardKey,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white12,
                              width: 1.0,
                            ),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: level.gridSize,
                                  crossAxisSpacing: 3,
                                  mainAxisSpacing: 3,
                                ),
                            itemCount: level.gridSize * level.gridSize,
                            itemBuilder: (context, index) {
                              final r = index ~/ level.gridSize;
                              final c = index % level.gridSize;
                              final cellVal = state.board[r][c];
                              final isPreviewCell = previewCells.contains(
                                '$r,$c',
                              );
                              final isLineGlowing =
                                  glowingRows.contains(r) ||
                                  glowingCols.contains(c);

                              Widget cellWidget;

                              if (cellVal > 0) {
                                final Color color;
                                IconData? overlayIcon;
                                if (cellVal == 9) {
                                  color = const Color(0xFF00B4D8);
                                  overlayIcon = Icons.ac_unit_rounded;
                                } else if (cellVal == 10) {
                                  color = const Color(0xFFFFB703);
                                  overlayIcon = Icons.diamond_rounded;
                                } else {
                                  color =
                                      AppColors.blockColors[(cellVal - 1) %
                                          AppColors.blockColors.length];
                                }
                                final isClearing =
                                    state.clearingRows.contains(r) ||
                                    state.clearingCols.contains(c);
                                final isJustPlaced =
                                    state.isAnimating && !isClearing;

                                cellWidget = LayoutBuilder(
                                  builder: (context, box) {
                                    final block = _buildGlossyBlock(
                                      color,
                                      box.maxWidth,
                                      box.maxHeight,
                                      overlayIcon: overlayIcon,
                                    );
                                    if (isClearing) {
                                      return TweenAnimationBuilder<double>(
                                        tween: Tween<double>(
                                          begin: 0.0,
                                          end: 1.0,
                                        ),
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeOutBack,
                                        builder: (context, value, child) {
                                          return Transform.rotate(
                                            angle: value * math.pi * 2,
                                            child: Transform.scale(
                                              scale: (1.0 - value).clamp(
                                                0.0,
                                                1.0,
                                              ),
                                              child: Opacity(
                                                opacity: (1.0 - value).clamp(
                                                  0.0,
                                                  1.0,
                                                ),
                                                child: child,
                                              ),
                                            ),
                                          );
                                        },
                                        child: block,
                                      );
                                    } else if (isJustPlaced) {
                                      return TweenAnimationBuilder<double>(
                                        tween: Tween<double>(
                                          begin: 1.0,
                                          end: 1.15,
                                        ),
                                        duration: const Duration(
                                          milliseconds: 75,
                                        ),
                                        curve: Curves.easeInOut,
                                        builder: (context, value, child) {
                                          return Transform.scale(
                                            scale: value,
                                            child: child,
                                          );
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
                                        tween: Tween<double>(
                                          begin: 0.2,
                                          end: 0.8,
                                        ),
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
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
                                cellWidget = AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    final pulse = isLineGlowing
                                        ? (0.2 + 0.35 * _pulseController.value)
                                        : 0.0;
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: isLineGlowing
                                            ? Colors.white.withValues(
                                                alpha: pulse,
                                              )
                                            : Colors.black26,
                                        borderRadius: BorderRadius.circular(4),
                                        border: isLineGlowing
                                            ? Border.all(
                                                color: AppColors.primary
                                                    .withValues(
                                                      alpha:
                                                          0.5 +
                                                          0.5 *
                                                              _pulseController
                                                                  .value,
                                                    ),
                                                width: 1.5,
                                              )
                                            : null,
                                        boxShadow: isLineGlowing
                                            ? [
                                                BoxShadow(
                                                  color: AppColors.primary
                                                      .withValues(
                                                        alpha: pulse * 0.8,
                                                      ),
                                                  blurRadius: 6,
                                                  spreadRadius: 1,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    );
                                  },
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
                                  if (_selectedPieceIndex != null &&
                                      _hoveredStartRow == r &&
                                      _hoveredStartCol == c) {
                                    setState(() {
                                      _hoveredStartRow = null;
                                      _hoveredStartCol = null;
                                    });
                                  }
                                },
                                child: InkWell(
                                  onTap: () {
                                    if (_selectedPieceIndex != null &&
                                        cellVal == 0) {
                                      final placed = ref
                                          .read(gameViewModelProvider.notifier)
                                          .placePiece(
                                            _selectedPieceIndex!,
                                            r,
                                            c,
                                          );
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
                          ),
                        ),
                        ShatterParticleOverlay(
                          key: _shatterKey,
                          gridSize: level.gridSize,
                        ),
                      ],
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
                  if (piece == null)
                    return const Expanded(child: SizedBox.shrink());

                  final colorIdx = state.pieceColors[pIdx];
                  final color = AppColors
                      .blockColors[colorIdx % AppColors.blockColors.length];
                  final isSelected = _selectedPieceIndex == pIdx;

                  return Expanded(
                    child: LayoutBuilder(
                      builder: (context, pieceBox) {
                        final maxScaleW =
                            (pieceBox.maxWidth - 20) / piece.cols - 2.0;
                        final maxScaleH =
                            (pieceBox.maxHeight - 20) / piece.rows - 2.0;
                        final blockSize = math.max(
                          8.0,
                          math.min(24.0, math.min(maxScaleW, maxScaleH)),
                        );

                        double boardBlockSize =
                            (MediaQuery.of(context).size.width - 48.0) /
                            level.gridSize;
                        final RenderBox? bBox =
                            _boardKey.currentContext?.findRenderObject()
                                as RenderBox?;
                        if (bBox != null && bBox.hasSize) {
                          boardBlockSize =
                              (bBox.size.width - 16.0) / level.gridSize;
                        }

                        return Center(
                          child: Draggable<int>(
                            data: pIdx,
                            dragAnchorStrategy: (draggable, context, position) {
                              final double pieceW = piece.cols * boardBlockSize;
                              final double pieceH = piece.rows * boardBlockSize;
                              return Offset(pieceW / 2, pieceH + 75.0);
                            },
                            onDragStarted: () {
                              HapticFeedback.mediumImpact();
                              setState(() {
                                _selectedPieceIndex = null;
                              });
                            },
                            onDragUpdate: (details) {
                              _updateDragHover(
                                pIdx,
                                details.globalPosition,
                                piece,
                                level.gridSize,
                              );
                            },
                            onDragEnd: (details) {
                              if (_hoveredStartRow != null &&
                                  _hoveredStartCol != null &&
                                  _hoveredPieceIndex == pIdx) {
                                final placed = ref
                                    .read(gameViewModelProvider.notifier)
                                    .placePiece(
                                      pIdx,
                                      _hoveredStartRow!,
                                      _hoveredStartCol!,
                                    );
                                if (placed) {
                                  HapticFeedback.mediumImpact();
                                }
                              }
                              setState(() {
                                _hoveredPieceIndex = null;
                                _hoveredStartRow = null;
                                _hoveredStartCol = null;
                              });
                            },
                            feedback: Material(
                              color: Colors.transparent,
                              child: Opacity(
                                opacity: 0.9,
                                child: Container(
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.4),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: _buildPiecePreview(
                                    piece,
                                    color,
                                    scale: boardBlockSize,
                                  ),
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.15,
                              child: _buildPiecePreview(
                                piece,
                                color,
                                scale: blockSize,
                              ),
                            ),
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _selectedPieceIndex = isSelected
                                      ? null
                                      : pIdx;
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
                                      ? Border.all(
                                          color: AppColors.primary,
                                          width: 2.0,
                                        )
                                      : null,
                                ),
                                child: _buildPiecePreview(
                                  piece,
                                  color,
                                  scale: blockSize,
                                ),
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

  Widget _buildPiecePreview(
    BlockShape piece,
    Color color, {
    double scale = 18,
  }) {
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

  Widget _buildGlossyBlock(
    Color color,
    double width,
    double height, {
    bool isPreview = false,
    IconData? overlayIcon,
  }) {
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
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  offset: const Offset(0, 1.5),
                  blurRadius: 2.0,
                ),
              ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(width, height),
            painter: ChiseledBlockPainter(color: color, isPreview: isPreview),
          ),
          if (overlayIcon != null && !isPreview)
            Icon(
              overlayIcon,
              size: math.max(10.0, width * 0.55),
              color: Colors.white.withValues(alpha: 0.95),
            ),
        ],
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
            border: Border.all(color: Colors.white24, width: 1.0),
          ),
          child: Icon(icon, size: iconSize, color: AppColors.headingDark),
        ),
      ),
    );
  }

  Widget _animatedStat(String label, int targetValue, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.headingDark),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: targetValue.toDouble()),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, val, child) {
            return FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${val.toInt()}',
                style: const TextStyle(
                  color: AppColors.headingDark,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.subtext,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.headingDark),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.headingDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.subtext,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _objectiveStat(
    String label, {
    required int frozen,
    required int gems,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (frozen > 0) ...[
              const Icon(
                Icons.ac_unit_rounded,
                size: 16,
                color: Color(0xFF00B4D8),
              ),
              const SizedBox(width: 2),
              Text(
                '$frozen',
                style: const TextStyle(
                  color: AppColors.headingDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (gems > 0) const SizedBox(width: 6),
            ] else if (frozen == 0) ...[
              const Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: Colors.green,
              ),
              if (gems > 0) const SizedBox(width: 6),
            ],
            if (gems > 0) ...[
              const Icon(
                Icons.diamond_rounded,
                size: 16,
                color: Color(0xFFFFB703),
              ),
              const SizedBox(width: 2),
              Text(
                '$gems',
                style: const TextStyle(
                  color: AppColors.headingDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ] else if (gems == 0) ...[
              const Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: Colors.green,
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.subtext,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(width: 1.0, height: 30, color: AppColors.gridLines);
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
              const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'NO MORE MOVES!',
                  style: TextStyle(
                    color: AppColors.headingDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Final Score: ${state.score}',
                  style: const TextStyle(
                    color: AppColors.subtext,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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
            border: Border.all(color: Colors.white24, width: 1.0),
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
                  border: Border.all(color: Colors.white24, width: 1.0),
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
                    color: AppColors.headingDark,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
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
                              .loadRandomLevel(
                                state.randomDifficulty ?? 'Easy',
                              );
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  GameView(levelNumber: widget.levelNumber + 1),
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
                        Uri.parse('https://ko-fi.com/sidhant947'),
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

class ShatterFragment {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double rotation;
  double vRotation;
  Color color;
  double alpha;

  ShatterFragment({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.rotation,
    required this.vRotation,
    required this.color,
    this.alpha = 1.0,
  });

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy += 450.0 * dt;
    rotation += vRotation * dt;
    alpha = (alpha - 1.8 * dt).clamp(0.0, 1.0);
  }
}

class ShatterParticleOverlay extends StatefulWidget {
  final int gridSize;

  const ShatterParticleOverlay({super.key, required this.gridSize});

  @override
  State<ShatterParticleOverlay> createState() => _ShatterParticleOverlayState();
}

class _ShatterParticleOverlayState extends State<ShatterParticleOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<ShatterFragment> _fragments = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..addListener(_tick);
  }

  void _tick() {
    final dt = 0.016;
    for (final f in _fragments) {
      f.update(dt);
    }
    setState(() {});
  }

  void triggerShatter({
    required Set<int> clearingRows,
    required Set<int> clearingCols,
    required List<List<int>> board,
  }) {
    _fragments.clear();
    final N = widget.gridSize;

    for (int r = 0; r < N; r++) {
      for (int c = 0; c < N; c++) {
        if (clearingRows.contains(r) || clearingCols.contains(c)) {
          final cellVal = board[r][c];
          final color = cellVal > 0
              ? AppColors.blockColors[(cellVal - 1) %
                    AppColors.blockColors.length]
              : AppColors.primary;

          final cx = (c + 0.5) / N;
          final cy = (r + 0.5) / N;

          for (int i = 0; i < 6; i++) {
            final angle = _random.nextDouble() * math.pi * 2;
            final speed = 150.0 + _random.nextDouble() * 250.0;
            _fragments.add(
              ShatterFragment(
                x: cx,
                y: cy,
                vx: math.cos(angle) * speed,
                vy: math.sin(angle) * speed - 60.0,
                size: 4.0 + _random.nextDouble() * 6.0,
                rotation: _random.nextDouble() * math.pi,
                vRotation: (_random.nextDouble() - 0.5) * 12.0,
                color: color,
              ),
            );
          }
        }
      }
    }

    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isAnimating || _fragments.isEmpty)
      return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _ShatterPainter(
            _fragments,
            constraints.maxWidth,
            constraints.maxHeight,
          ),
        );
      },
    );
  }
}

class _ShatterPainter extends CustomPainter {
  final List<ShatterFragment> fragments;
  final double width;
  final double height;

  _ShatterPainter(this.fragments, this.width, this.height);

  @override
  void paint(Canvas canvas, Size size) {
    for (final f in fragments) {
      if (f.alpha <= 0) continue;
      final px = f.x * width;
      final py = f.y * height;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(f.rotation);

      final paint = Paint()
        ..color = f.color.withValues(alpha: f.alpha)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: f.size, height: f.size),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ShatterPainter oldDelegate) => true;
}

class ComboCalloutOverlay extends StatefulWidget {
  const ComboCalloutOverlay({super.key});

  @override
  State<ComboCalloutOverlay> createState() => _ComboCalloutOverlayState();
}

class _ComboCalloutOverlayState extends State<ComboCalloutOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  String _title = '';
  Color _color = AppColors.primary;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.2, end: 1.3), weight: 35),
      TweenSequenceItem(tween: Tween<double>(begin: 1.3, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.1), weight: 40),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  void triggerCallout({required int clearedLines, required int combo}) {
    if (clearedLines <= 0) return;

    if (clearedLines >= 4) {
      _title = 'BLOCK BLAST!!! ⚡';
      _color = const Color(0xFFFF0055);
    } else if (clearedLines == 3) {
      _title = 'TRIPLE CLEAR!! 💥';
      _color = const Color(0xFFFF9F1C);
    } else if (clearedLines == 2) {
      _title = 'DOUBLE CLEAR! 🔥';
      _color = const Color(0xFF2EC4B6);
    } else if (combo > 1) {
      _title = 'COMBO x$combo! ⚡';
      _color = AppColors.primary;
    } else {
      return;
    }

    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (!_controller.isAnimating && _controller.isCompleted) {
          return const SizedBox.shrink();
        }
        if (_title.isEmpty) return const SizedBox.shrink();

        final flashAlpha = (0.25 * (1.0 - _controller.value)).clamp(0.0, 0.25);

        return Stack(
          children: [
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _color.withValues(alpha: flashAlpha * 2),
                    width: 6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _color.withValues(alpha: flashAlpha),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.22,
              left: 0,
              right: 0,
              child: Center(
                child: Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _color,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
          color: AppColors
              .blockColors[_random.nextInt(AppColors.blockColors.length)],
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

class _FloatingScoreOverlayState extends State<FloatingScoreOverlay>
    with SingleTickerProviderStateMixin {
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
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _translateY = Tween<double>(
      begin: 0.0,
      end: -100.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '+${widget.lastScore}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.combo > 1)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9F1C),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'COMBO x${widget.combo}!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
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

  ChiseledBlockPainter({required this.color, required this.isPreview});

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

    final topHighlight = hsl
        .withLightness(math.min(1.0, hsl.lightness + 0.28))
        .toColor();
    final topHighlightEnd = hsl
        .withLightness(math.min(1.0, hsl.lightness + 0.12))
        .toColor();

    final leftHighlight = hsl
        .withLightness(math.min(1.0, hsl.lightness + 0.18))
        .toColor();
    final leftHighlightEnd = hsl
        .withLightness(math.min(1.0, hsl.lightness + 0.05))
        .toColor();

    final bottomShadow = hsl
        .withLightness(math.max(0.0, hsl.lightness - 0.18))
        .toColor();
    final bottomShadowEnd = hsl
        .withLightness(math.max(0.0, hsl.lightness - 0.28))
        .toColor();

    final rightShadow = hsl
        .withLightness(math.max(0.0, hsl.lightness - 0.22))
        .toColor();
    final rightShadowEnd = hsl
        .withLightness(math.max(0.0, hsl.lightness - 0.32))
        .toColor();

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
          topHighlightEnd.withValues(alpha: isPreview ? 0.3 : 0.6),
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
          leftHighlightEnd.withValues(alpha: isPreview ? 0.2 : 0.5),
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
          bottomShadow.withValues(alpha: isPreview ? 0.4 : 0.8),
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
          rightShadow.withValues(alpha: isPreview ? 0.3 : 0.7),
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
    return oldDelegate.color != color || oldDelegate.isPreview != isPreview;
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

class _ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
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
        final shake =
            math.sin(_animation.value * math.pi * 4) *
            8.0 *
            (1 - _animation.value);
        return Transform.translate(offset: Offset(shake, 0), child: child);
      },
      child: widget.child,
    );
  }
}
