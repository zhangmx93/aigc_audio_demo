import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ThumbnailTimeline extends StatefulWidget {
  final List<String> thumbnails;
  final bool isGeneratingThumbs;
  final Duration duration;
  final double trimStart;
  final double trimEnd;
  final Function(double) onTrimStartChanged;
  final Function(double) onTrimEndChanged;
  final bool isPlaying;
  final double height;
  
  static const double _handleWidth = 10.0;
  static const double _handleTouchArea = 40.0; // Increased touch area
  static const double _minSelectionSeconds = 0.1;

  const ThumbnailTimeline({
    super.key,
    required this.thumbnails,
    required this.isGeneratingThumbs,
    required this.duration,
    required this.trimStart,
    required this.trimEnd,
    required this.onTrimStartChanged,
    required this.onTrimEndChanged,
    required this.isPlaying,
    this.height = 50.0,
  });

  @override
  State<ThumbnailTimeline> createState() => _ThumbnailTimelineState();
}

class _ThumbnailTimelineState extends State<ThumbnailTimeline> {
  final ScrollController _scrollController = ScrollController();
  bool _isDraggingHandle = false;
  String? _activeHandle; // 'left' or 'right'

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewWidth = constraints.maxWidth;
          final totalSec = widget.duration.inMilliseconds / 1000.0;
          final count = widget.thumbnails.length;
          
          // If no thumbnails, show empty state
          if (count == 0) {
            return Container(
              width: viewWidth,
              height: widget.height,
              color: Colors.black12,
              child: widget.isGeneratingThumbs
                  ? const Center(child: CircularProgressIndicator())
                  : const Center(child: Text('无缩略图', style: TextStyle(color: Colors.grey))),
            );
          }
          
          final thumbnailWidth = widget.height * (16 / 9); 
          final totalContentWidth = thumbnailWidth * count;
          
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // Block scroll when dragging handle
              return _isDraggingHandle;
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalContentWidth.clamp(viewWidth, double.infinity),
                height: widget.height,
                child: LayoutBuilder(
                  builder: (context, contentConstraints) {
                    final contentWidth = contentConstraints.maxWidth;
                    
                    double secToDx(double sec) => (sec / totalSec) * contentWidth;
                    double dxToSec(double dx) => (dx / contentWidth) * totalSec;

                    final leftDx = secToDx(widget.trimStart);
                    final rightDx = secToDx(widget.trimEnd);

                    return Stack(
                      children: [
                        // Thumbnails row
                        Row(
                          children: [
                            for (int i = 0; i < count; i++)
                              SizedBox(
                                width: thumbnailWidth,
                                height: widget.height,
                                child: widget.thumbnails.length > i
                                    ? Image.file(
                                        File(widget.thumbnails[i]),
                                        fit: BoxFit.contain,
                                      )
                                    : Container(
                                        color: Colors.black12,
                                        child: widget.isGeneratingThumbs
                                            ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                                            : const SizedBox.shrink(),
                                      ),
                              ),
                          ],
                        ),

                        // Shaded outside area
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ShadePainter(
                              left: leftDx,
                              right: rightDx,
                              handleWidth: ThumbnailTimeline._handleWidth,
                            ),
                          ),
                        ),

                        // Left handle - using Listener for more control
                        Positioned(
                          left: (leftDx - ThumbnailTimeline._handleTouchArea / 2).clamp(0.0, contentWidth - ThumbnailTimeline._handleTouchArea),
                          top: 0,
                          bottom: 0,
                          child: Listener(
                            onPointerDown: (event) {
                              if (kDebugMode) {
                                print('[ThumbnailTimeline] 开始触摸左手柄');
                              }
                              setState(() {
                                _isDraggingHandle = true;
                                _activeHandle = 'left';
                              });
                            },
                            onPointerMove: (event) {
                              if (_activeHandle == 'left') {
                                if (kDebugMode) {
                                  print('[ThumbnailTimeline] 拖拽左手柄: ${event.delta.dx}');
                                }
                                final dx = (leftDx + event.delta.dx).clamp(0.0, rightDx - ThumbnailTimeline._handleWidth);
                                final newStart = dxToSec(dx);
                                final minEnd = newStart + ThumbnailTimeline._minSelectionSeconds;
                                widget.onTrimStartChanged(newStart.clamp(0.0, totalSec));
                                if (widget.trimEnd < minEnd) {
                                  widget.onTrimEndChanged(minEnd.clamp(0.0, totalSec));
                                }
                              }
                            },
                            onPointerUp: (event) {
                              if (kDebugMode) {
                                print('[ThumbnailTimeline] 结束触摸左手柄');
                              }
                              setState(() {
                                _isDraggingHandle = false;
                                _activeHandle = null;
                              });
                            },
                            child: Container(
                              width: ThumbnailTimeline._handleTouchArea,
                              height: widget.height,
                              color: Colors.red.withValues(alpha: 0.3), // Debug background
                              child: Center(
                                child: _HandleWidget(isLeft: true, height: widget.height, width: ThumbnailTimeline._handleWidth),
                              ),
                            ),
                          ),
                        ),

                        // Right handle - using Listener for more control
                        Positioned(
                          left: (rightDx - ThumbnailTimeline._handleTouchArea / 2).clamp(0.0, contentWidth - ThumbnailTimeline._handleTouchArea),
                          top: 0,
                          bottom: 0,
                          child: Listener(
                            onPointerDown: (event) {
                              if (kDebugMode) {
                                print('[ThumbnailTimeline] 开始触摸右手柄');
                              }
                              setState(() {
                                _isDraggingHandle = true;
                                _activeHandle = 'right';
                              });
                            },
                            onPointerMove: (event) {
                              if (_activeHandle == 'right') {
                                if (kDebugMode) {
                                  print('[ThumbnailTimeline] 拖拽右手柄: ${event.delta.dx}');
                                }
                                final dx = (rightDx + event.delta.dx).clamp(leftDx + ThumbnailTimeline._handleWidth, contentWidth);
                                final newEnd = dxToSec(dx);
                                final minEnd = widget.trimStart + ThumbnailTimeline._minSelectionSeconds;
                                widget.onTrimEndChanged(newEnd.clamp(minEnd, totalSec));
                              }
                            },
                            onPointerUp: (event) {
                              if (kDebugMode) {
                                print('[ThumbnailTimeline] 结束触摸右手柄');
                              }
                              setState(() {
                                _isDraggingHandle = false;
                                _activeHandle = null;
                              });
                            },
                            child: Container(
                              width: ThumbnailTimeline._handleTouchArea,
                              height: widget.height,
                              color: Colors.blue.withValues(alpha: 0.3), // Debug background
                              child: Center(
                                child: _HandleWidget(isLeft: false, height: widget.height, width: ThumbnailTimeline._handleWidth),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ShadePainter extends CustomPainter {
  final double left;
  final double right;
  final double handleWidth;
  _ShadePainter({required this.left, required this.right, required this.handleWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paintShade = Paint()..color = const Color(0x88000000);
    // Left shaded area
    canvas.drawRect(Rect.fromLTWH(0, 0, left, size.height), paintShade);
    // Right shaded area
    canvas.drawRect(Rect.fromLTWH(right, 0, size.width - right, size.height), paintShade);
    // Selection border
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(Rect.fromLTWH(left, 0, right - left, size.height), border);
  }

  @override
  bool shouldRepaint(covariant _ShadePainter oldDelegate) {
    return oldDelegate.left != left || oldDelegate.right != right || oldDelegate.handleWidth != handleWidth;
  }
}

class _HandleWidget extends StatelessWidget {
  final bool isLeft;
  final double height;
  final double width;
  const _HandleWidget({required this.isLeft, required this.height, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: isLeft ? const BorderSide(color: Colors.blueAccent, width: 3) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: Colors.blueAccent, width: 3) : BorderSide.none,
        ),
      ),
      child: Center(
        child: Container(
          width: 3,
          height: height * 0.6,
          color: Colors.blueAccent,
        ),
      ),
    );
  }
}