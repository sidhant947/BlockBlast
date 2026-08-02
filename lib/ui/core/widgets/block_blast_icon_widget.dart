import 'package:flutter/material.dart';

class BlockBlastIconWidget extends StatelessWidget {
  const BlockBlastIconWidget({
    super.key,
    this.size = 56,
    this.color = const Color(0xFF38B6FF),
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cellSize = size * 0.28;
    final spacing = size * 0.05;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: size * 0.1,
            top: size * 0.1,
            child: _buildTile(cellSize, color),
          ),
          Positioned(
            left: size * 0.1 + cellSize + spacing,
            top: size * 0.1,
            child: _buildTile(cellSize, color),
          ),
          Positioned(
            left: size * 0.1 + (cellSize + spacing) * 2,
            top: size * 0.1,
            child: _buildTile(cellSize, color),
          ),
          Positioned(
            left: size * 0.1 + cellSize + spacing,
            top: size * 0.1 + cellSize + spacing,
            child: _buildTile(cellSize, const Color(0xFFFF9F1C)),
          ),
          Positioned(
            left: size * 0.1 + cellSize + spacing,
            top: size * 0.1 + (cellSize + spacing) * 2,
            child: _buildTile(cellSize, const Color(0xFFFF9F1C)),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(double tileSize, Color tileColor) {
    return Container(
      width: tileSize,
      height: tileSize,
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(tileSize * 0.2),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 2,
            offset: const Offset(1, 1),
          ),
        ],
      ),
    );
  }
}
