import 'dart:ui';
import 'package:flutter/material.dart';

class DPad extends StatelessWidget {
  final Function(int dx, int dy) onDirectionPressed;
  final double scale;

  const DPad({
    Key? key,
    required this.onDirectionPressed,
    this.scale = 1.0,
  }) : super(key: key);

  Widget _buildDpadButton({
    required IconData icon,
    required VoidCallback onPressed,
    required double width,
    required double height,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16 * scale),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            border: Border.all(
              color: Colors.cyanAccent.withOpacity(0.36),
              width: 1.5 * scale,
            ),
            borderRadius: BorderRadius.circular(16 * scale),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withOpacity(0.08),
                blurRadius: 12 * scale,
                spreadRadius: 2 * scale,
              )
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              highlightColor: Colors.cyanAccent.withOpacity(0.24),
              splashColor: Colors.cyanAccent.withOpacity(0.12),
              child: Center(
                child: Icon(
                  icon,
                  color: Colors.cyanAccent,
                  size: 28 * scale,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double btnSize = 58.0 * scale;
    final double spacing = 4.0 * scale;
    
    return Container(
      width: btnSize * 3 + spacing * 2,
      height: btnSize * 3 + spacing * 2,
      child: Stack(
        children: [
          // UP
          Positioned(
            left: btnSize + spacing,
            top: 0,
            child: _buildDpadButton(
              icon: Icons.keyboard_arrow_up,
              onPressed: () => onDirectionPressed(0, -1),
              width: btnSize,
              height: btnSize,
            ),
          ),
          // DOWN
          Positioned(
            left: btnSize + spacing,
            bottom: 0,
            child: _buildDpadButton(
              icon: Icons.keyboard_arrow_down,
              onPressed: () => onDirectionPressed(0, 1),
              width: btnSize,
              height: btnSize,
            ),
          ),
          // LEFT
          Positioned(
            left: 0,
            top: btnSize + spacing,
            child: _buildDpadButton(
              icon: Icons.keyboard_arrow_left,
              onPressed: () => onDirectionPressed(-1, 0),
              width: btnSize,
              height: btnSize,
            ),
          ),
          // RIGHT
          Positioned(
            right: 0,
            top: btnSize + spacing,
            child: _buildDpadButton(
              icon: Icons.keyboard_arrow_right,
              onPressed: () => onDirectionPressed(1, 0),
              width: btnSize,
              height: btnSize,
            ),
          ),
          // CENTER DECORATOR
          Positioned(
            left: btnSize + spacing + 12 * scale,
            top: btnSize + spacing + 12 * scale,
            child: Container(
              width: btnSize - 24 * scale,
              height: btnSize - 24 * scale,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.cyanAccent.withOpacity(0.18),
                  width: 1,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
