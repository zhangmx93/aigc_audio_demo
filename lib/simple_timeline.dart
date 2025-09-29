import 'dart:io';
import 'package:flutter/material.dart';

class SimpleTimeline extends StatefulWidget {
  final List<String> thumbnails;
  final bool isGenerating;
  final int thumbCount;
  final double trimStart;
  final double trimEnd;
  final double duration;
  final Function(double, double) onTrimChanged;
  
  const SimpleTimeline({
    super.key,
    required this.thumbnails,
    required this.isGenerating,
    required this.thumbCount,
    required this.trimStart,
    required this.trimEnd,
    required this.duration,
    required this.onTrimChanged,
  });

  @override
  State<SimpleTimeline> createState() => _SimpleTimelineState();
}

class _SimpleTimelineState extends State<SimpleTimeline> {
  final ScrollController _scrollController = ScrollController();
  static const double thumbWidth = 80.0;
  static const double handleWidth = 10.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contentWidth = widget.thumbCount * thumbWidth;
    
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          // Thumbnails
          SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: Container(
              width: contentWidth,
              height: 60,
              child: Row(
                children: [
                  for (int i = 0; i < widget.thumbCount; i++)
                    Container(
                      width: thumbWidth,
                      height: 60,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400, width: 0.5),
                      ),
                      child: widget.thumbnails.length > i
                          ? Image.file(
                              File(widget.thumbnails[i]),
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: widget.isGenerating
                                  ? const Center(
                                      child: SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(strokeWidth: 1.5),
                                      ),
                                    )
                                  : Icon(Icons.image, color: Colors.grey.shade400, size: 16),
                            ),
                    ),
                ],
              ),
            ),
          ),
          
          // Selection overlay
          Positioned.fill(
            child: CustomPaint(
              painter: SelectionPainter(
                trimStart: widget.trimStart,
                trimEnd: widget.trimEnd,
                duration: widget.duration,
                contentWidth: contentWidth,
                scrollController: _scrollController,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SelectionPainter extends CustomPainter {
  final double trimStart;
  final double trimEnd;
  final double duration;
  final double contentWidth;
  final ScrollController scrollController;

  SelectionPainter({
    required this.trimStart,
    required this.trimEnd,
    required this.duration,
    required this.contentWidth,
    required this.scrollController,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (duration <= 0) return;

    final scrollOffset = scrollController.hasClients ? scrollController.offset : 0.0;
    
    // Calculate positions
    final leftContentX = (trimStart / duration) * contentWidth;
    final rightContentX = (trimEnd / duration) * contentWidth;
    
    final leftViewportX = leftContentX - scrollOffset;
    final rightViewportX = rightContentX - scrollOffset;

    // Draw shaded areas
    final shadePaint = Paint()..color = const Color(0x88000000);
    
    // Left shade
    if (leftViewportX > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, leftViewportX.clamp(0.0, size.width), size.height),
        shadePaint,
      );
    }
    
    // Right shade
    if (rightViewportX < size.width) {
      final startX = rightViewportX.clamp(0.0, size.width);
      canvas.drawRect(
        Rect.fromLTWH(startX, 0, size.width - startX, size.height),
        shadePaint,
      );
    }

    // Draw selection border
    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final selectionLeft = leftViewportX.clamp(0.0, size.width);
    final selectionRight = rightViewportX.clamp(0.0, size.width);
    
    if (selectionRight > selectionLeft) {
      canvas.drawRect(
        Rect.fromLTWH(
          selectionLeft,
          0,
          selectionRight - selectionLeft,
          size.height,
        ),
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SelectionPainter oldDelegate) {
    return oldDelegate.trimStart != trimStart ||
        oldDelegate.trimEnd != trimEnd ||
        oldDelegate.duration != duration;
  }
}