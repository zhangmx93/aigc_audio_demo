import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class JianyingTimeline extends StatefulWidget {
  final List<String> thumbnails;
  final bool isGeneratingThumbs;
  final Duration duration;
  final double trimStart;
  final double trimEnd;
  final Duration currentPosition;
  final Function(double) onTrimStartChanged;
  final Function(double) onTrimEndChanged;
  final Function(Duration) onSeek;
  final VoidCallback? onSplit;
  final bool isPlaying;
  final bool isMuted;
  final VoidCallback? onMuteToggle;
  final Function(String?)? onAudioFileSelected;
  final String? customAudioPath;
  final double height;
  
  const JianyingTimeline({
    super.key,
    required this.thumbnails,
    required this.isGeneratingThumbs,
    required this.duration,
    required this.trimStart,
    required this.trimEnd,
    required this.currentPosition,
    required this.onTrimStartChanged,
    required this.onTrimEndChanged,
    required this.onSeek,
    required this.isPlaying,
    this.onSplit,
    this.isMuted = false,
    this.onMuteToggle,
    this.onAudioFileSelected,
    this.customAudioPath,
    this.height = 180.0,
  });

  @override
  State<JianyingTimeline> createState() => _JianyingTimelineState();
}

class _JianyingTimelineState extends State<JianyingTimeline> {
  final ScrollController _timeRulerScrollController = ScrollController();
  final ScrollController _videoTrackScrollController = ScrollController();
  bool _isDraggingHandle = false;
  bool _isDraggingPlayhead = false;
  String? _activeHandle;
  double _scale = 1.0; // Timeline zoom scale
  bool _isSyncing = false; // Prevent infinite sync loops
  
  static const double _handleWidth = 8.0;
  static const double _handleTouchArea = 32.0;
  static const double _playheadWidth = 2.0;
  static const double _timeRulerHeight = 30.0;
  static const double _trackHeight = 80.0;
  static const double _minSelectionSeconds = 0.1;

  @override
  void initState() {
    super.initState();
    // Sync scroll controllers
    _timeRulerScrollController.addListener(_syncTimeRulerScroll);
    _videoTrackScrollController.addListener(_syncVideoTrackScroll);
  }

  void _syncTimeRulerScroll() {
    if (!_isSyncing && _videoTrackScrollController.hasClients) {
      _isSyncing = true;
      _videoTrackScrollController.jumpTo(_timeRulerScrollController.offset);
      _isSyncing = false;
    }
  }

  void _syncVideoTrackScroll() {
    if (!_isSyncing && _timeRulerScrollController.hasClients) {
      _isSyncing = true;
      _timeRulerScrollController.jumpTo(_videoTrackScrollController.offset);
      _isSyncing = false;
    }
  }

  @override
  void dispose() {
    _timeRulerScrollController.dispose();
    _videoTrackScrollController.dispose();
    super.dispose();
  }

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final milliseconds = (duration.inMilliseconds % 1000) ~/ 100;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.$milliseconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      color: const Color(0xFF1A1A1A), // Dark background like Jianying
      child: Column(
        children: [
          // Time ruler
          _buildTimeRuler(),
          // Video track with thumbnails
          Expanded(child: _buildVideoTrack()),
          // Controls
          _buildControls(),
          // Audio track controls
          if (widget.onAudioFileSelected != null) _buildAudioTrackControls(),
        ],
      ),
    );
  }

  Widget _buildTimeRuler() {
    return Container(
      height: _timeRulerHeight,
      color: const Color(0xFF2A2A2A),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewWidth = constraints.maxWidth;
          final totalSec = widget.duration.inMilliseconds / 1000.0;
          final count = widget.thumbnails.length;
          
          // Use same width calculation as video track
          final thumbnailWidth = (_trackHeight * (16 / 9)) * _scale;
          final muteButtonWidth = widget.onMuteToggle != null ? 40.0 : 0.0;
          final totalContentWidth = count > 0 
              ? thumbnailWidth * count + muteButtonWidth
              : viewWidth * _scale;
          final timeRulerWidth = totalContentWidth - muteButtonWidth;
          final pixelsPerSecond = timeRulerWidth / totalSec;
          
          return SingleChildScrollView(
            controller: _timeRulerScrollController,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Row(
              children: [
                // Empty space to align with mute button
                if (widget.onMuteToggle != null)
                  SizedBox(width: muteButtonWidth),
                // Time ruler content
                SizedBox(
                  width: timeRulerWidth,
                  height: _timeRulerHeight,
                  child: CustomPaint(
                    painter: _TimeRulerPainter(
                      duration: widget.duration,
                      pixelsPerSecond: pixelsPerSecond,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoTrack() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSec = widget.duration.inMilliseconds / 1000.0;
        final count = widget.thumbnails.length;
        
        if (count == 0) {
          return Container(
            color: const Color(0xFF333333),
            child: Center(
              child: widget.isGeneratingThumbs
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('无缩略图', style: TextStyle(color: Colors.grey)),
            ),
          );
        }
        
        final thumbnailWidth = (_trackHeight * (16 / 9)) * _scale;
        
        return SingleChildScrollView(
          controller: _videoTrackScrollController,
          scrollDirection: Axis.horizontal,
          physics: _isDraggingHandle || _isDraggingPlayhead 
              ? const NeverScrollableScrollPhysics() 
              : const ClampingScrollPhysics(),
          child: Row(
            children: [
              // Mute button on the left side of thumbnails
              if (widget.onMuteToggle != null)
                Container(
                  width: 40,
                  height: _trackHeight,
                  color: const Color(0xFF2A2A2A),
                  child: IconButton(
                    onPressed: widget.onMuteToggle,
                    icon: Icon(
                      widget.isMuted ? Icons.volume_off : Icons.volume_up,
                      color: widget.isMuted ? Colors.red : Colors.green,
                      size: 20,
                    ),
                    tooltip: widget.isMuted ? '取消静音' : '静音',
                  ),
                ),
              // Thumbnails area
              SizedBox(
                width: thumbnailWidth * count,
                height: _trackHeight,
                child: LayoutBuilder(
                  builder: (context, contentConstraints) {
                    final contentWidth = contentConstraints.maxWidth;
                    
                    double secToDx(double sec) => (sec / totalSec) * contentWidth;
                    double dxToSec(double dx) => (dx / contentWidth) * totalSec;

                    final leftDx = secToDx(widget.trimStart);
                    final rightDx = secToDx(widget.trimEnd);
                    final playheadDx = secToDx(widget.currentPosition.inMilliseconds / 1000.0);

                    return Container(
                      color: const Color(0xFF333333),
                      child: Stack(
                        children: [
                          // Background grid
                          CustomPaint(
                            size: Size(contentWidth, _trackHeight),
                            painter: _GridPainter(
                              width: contentWidth,
                              height: _trackHeight,
                            ),
                          ),
                          
                          // Thumbnails
                          _buildThumbnailsRow(contentWidth, count, thumbnailWidth),
                          
                          // Selection area
                          _buildSelectionArea(leftDx, rightDx),
                          
                          // Trim handles
                          _buildTrimHandles(contentWidth, leftDx, rightDx, totalSec, secToDx, dxToSec),
                          
                          // Playhead
                          _buildPlayhead(playheadDx, contentWidth, totalSec, dxToSec),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThumbnailsRow(double contentWidth, int count, double thumbnailWidth) {
    // Calculate safe number of slots to generate
    final slotsNeeded = (contentWidth / thumbnailWidth).ceil();
    
    return Positioned.fill(
      child: Stack(
        children: List.generate(
          slotsNeeded,
          (index) {
            // Safe index calculation - handle case when thumbnails are still generating
            final thumbIndex = count > 0 ? index % count : 0;
            final hasValidThumbnail = count > 0 && thumbIndex < widget.thumbnails.length;
            
            return Positioned(
              left: index * thumbnailWidth,
              top: 0,
              width: thumbnailWidth,
              height: _trackHeight,
              child: hasValidThumbnail
                  ? Container(
                      margin: const EdgeInsets.all(1),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Image.file(
                          File(widget.thumbnails[thumbIndex]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : Container(
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF444444),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: widget.isGeneratingThumbs
                          ? const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : null,
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSelectionArea(double leftDx, double rightDx) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: 0,
      child: CustomPaint(
        painter: _SelectionPainter(
          left: leftDx,
          right: rightDx,
          trackHeight: _trackHeight,
        ),
      ),
    );
  }

  Widget _buildTrimHandles(double contentWidth, double leftDx, double rightDx, 
      double totalSec, Function secToDx, Function dxToSec) {
    return Stack(
      children: [
        // Left handle
        _buildHandle(
          left: leftDx.clamp(0.0, contentWidth - _handleTouchArea),
          isLeft: true,
          onMove: (delta) {
            if (kDebugMode) {
              print('[JianyingTimeline] 左手柄移动: delta=$delta, leftDx=$leftDx, rightDx=$rightDx');
            }
            // 计算新位置，确保不超过右边界且保持最小间距
            final minDistancePixels = _minSelectionSeconds / totalSec * contentWidth;
            final maxPosition = rightDx - minDistancePixels;
            final newPosition = (leftDx + delta).clamp(0.0, maxPosition);
            final newStart = dxToSec(newPosition);
            
            if (kDebugMode) {
              print('[JianyingTimeline] 左手柄新位置: newPosition=$newPosition, newStart=$newStart');
            }
            
            widget.onTrimStartChanged(newStart);
          },
        ),
        
        // Right handle  
        _buildHandle(
          left: (rightDx - _handleTouchArea).clamp(0.0, contentWidth - _handleTouchArea),
          isLeft: false,
          onMove: (delta) {
            if (kDebugMode) {
              print('[JianyingTimeline] 右手柄移动: delta=$delta, leftDx=$leftDx, rightDx=$rightDx');
            }
            // 计算新位置，确保不超过左边界且保持最小间距
            final minDistancePixels = _minSelectionSeconds / totalSec * contentWidth;
            final minPosition = leftDx + minDistancePixels;
            final newPosition = (rightDx + delta).clamp(minPosition, contentWidth);
            final newEnd = dxToSec(newPosition);
            
            if (kDebugMode) {
              print('[JianyingTimeline] 右手柄新位置: newPosition=$newPosition, newEnd=$newEnd');
            }
            
            widget.onTrimEndChanged(newEnd);
          },
        ),
      ],
    );
  }

  Widget _buildHandle({
    required double left,
    required bool isLeft,
    required Function(double) onMove,
  }) {
    return Positioned(
      left: left,
      top: 0,
      bottom: 0,
      child: Listener(
        onPointerDown: (event) {
          setState(() {
            _isDraggingHandle = true;
            _activeHandle = isLeft ? 'left' : 'right';
          });
          if (kDebugMode) {
            print('[JianyingTimeline] 开始拖拽${isLeft ? '左' : '右'}手柄');
          }
        },
        onPointerMove: (event) {
          if (_activeHandle == (isLeft ? 'left' : 'right')) {
            onMove(event.delta.dx);
          }
        },
        onPointerUp: (event) {
          setState(() {
            _isDraggingHandle = false;
            _activeHandle = null;
          });
        },
        child: SizedBox(
          width: _handleTouchArea,
          height: _trackHeight,
          child: Center(
            child: Container(
              width: _handleWidth,
              height: _trackHeight,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700), // Gold color like Jianying
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 2,
                  height: _trackHeight * 0.8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayhead(double playheadDx, double contentWidth, double totalSec, Function dxToSec) {
    return Positioned(
      left: playheadDx - _playheadWidth / 2,
      top: 0,
      bottom: 0,
      child: Listener(
        onPointerDown: (event) {
          setState(() {
            _isDraggingPlayhead = true;
          });
        },
        onPointerMove: (event) {
          if (_isDraggingPlayhead) {
            final newDx = (playheadDx + event.delta.dx).clamp(0.0, contentWidth);
            final newSec = dxToSec(newDx);
            widget.onSeek(Duration(milliseconds: (newSec * 1000).round()));
          }
        },
        onPointerUp: (event) {
          setState(() {
            _isDraggingPlayhead = false;
          });
        },
        child: SizedBox(
          width: _playheadWidth + 10, // Larger touch area
          child: Center(
            child: Container(
              width: _playheadWidth,
              height: _trackHeight,
              decoration: BoxDecoration(
                color: const Color(0xFFFF4757), // Red playhead
                borderRadius: BorderRadius.circular(1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      height: 30,
      color: const Color(0xFF2A2A2A),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            _formatTime(widget.currentPosition),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const Text(' / ', style: TextStyle(color: Colors.grey, fontSize: 12)),
          Text(
            _formatTime(widget.duration),
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const Spacer(),
          if (widget.onSplit != null) ...[
            IconButton(
              onPressed: widget.onSplit,
              icon: const Icon(Icons.content_cut, color: Colors.white, size: 16),
              tooltip: '分割',
            ),
          ],
          IconButton(
            onPressed: () {
              final oldScale = _scale;
              final currentOffset = _videoTrackScrollController.hasClients ? _videoTrackScrollController.offset : 0.0;
              setState(() {
                _scale = (_scale * 1.2).clamp(0.5, 3.0);
              });
              // Adjust scroll position proportionally
              if (_videoTrackScrollController.hasClients) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final newOffset = currentOffset * (_scale / oldScale);
                  final maxScroll = _videoTrackScrollController.position.maxScrollExtent;
                  _videoTrackScrollController.jumpTo(newOffset.clamp(0.0, maxScroll));
                });
              }
            },
            icon: const Icon(Icons.zoom_in, color: Colors.white, size: 16),
            tooltip: '放大',
          ),
          IconButton(
            onPressed: () {
              final oldScale = _scale;
              final currentOffset = _videoTrackScrollController.hasClients ? _videoTrackScrollController.offset : 0.0;
              setState(() {
                _scale = (_scale / 1.2).clamp(0.5, 3.0);
              });
              // Adjust scroll position proportionally and clamp to prevent overflow
              if (_videoTrackScrollController.hasClients) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final newOffset = currentOffset * (_scale / oldScale);
                  final maxScroll = _videoTrackScrollController.position.maxScrollExtent;
                  _videoTrackScrollController.jumpTo(newOffset.clamp(0.0, maxScroll));
                });
              }
            },
            icon: const Icon(Icons.zoom_out, color: Colors.white, size: 16),
            tooltip: '缩小',
          ),
        ],
      ),
    );
  }

  Widget _buildAudioTrackControls() {
    return Container(
      height: 40,
      color: const Color(0xFF2A2A2A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.audiotrack, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Text(
            '音轨:',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(width: 8),
          if (widget.customAudioPath != null) ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade800.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.shade600, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.music_note, color: Colors.orange, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.customAudioPath!.split('/').last,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => widget.onAudioFileSelected?.call(null),
                      child: Icon(Icons.close, color: Colors.red.shade400, size: 16),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            GestureDetector(
              onTap: () async {
                // Simple file selection - you can implement file picker here
                widget.onAudioFileSelected?.call('placeholder_path');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade800.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.shade600, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add, color: Colors.orange, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '添加音频',
                      style: TextStyle(color: Colors.orange.shade200, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

}

class _TimeRulerPainter extends CustomPainter {
  final Duration duration;
  final double pixelsPerSecond;

  _TimeRulerPainter({required this.duration, required this.pixelsPerSecond});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final totalSeconds = duration.inSeconds;
    final interval = _getInterval(pixelsPerSecond);

    for (int i = 0; i <= totalSeconds; i += interval) {
      final x = i * pixelsPerSecond;
      if (x <= size.width) {
        // Draw tick
        canvas.drawLine(
          Offset(x, size.height - 10),
          Offset(x, size.height),
          paint,
        );

        // Draw time label
        if (i % (interval * 2) == 0) {
          final minutes = i ~/ 60;
          final seconds = i % 60;
          final timeText = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
          
          textPainter.text = TextSpan(
            text: timeText,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          );
          textPainter.layout();
          textPainter.paint(canvas, Offset(x + 2, 5));
        }
      }
    }
  }

  int _getInterval(double pixelsPerSecond) {
    if (pixelsPerSecond > 100) return 1;
    if (pixelsPerSecond > 50) return 2;
    if (pixelsPerSecond > 20) return 5;
    if (pixelsPerSecond > 10) return 10;
    return 30;
  }

  @override
  bool shouldRepaint(covariant _TimeRulerPainter oldDelegate) {
    return oldDelegate.duration != duration || oldDelegate.pixelsPerSecond != pixelsPerSecond;
  }
}

class _GridPainter extends CustomPainter {
  final double width;
  final double height;

  _GridPainter({required this.width, required this.height});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 0.5;

    // Draw vertical grid lines every 50 pixels
    for (double x = 0; x < width; x += 50) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.width != width || oldDelegate.height != height;
  }
}

class _SelectionPainter extends CustomPainter {
  final double left;
  final double right;
  final double trackHeight;

  _SelectionPainter({required this.left, required this.right, required this.trackHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final shadePaint = Paint()..color = Colors.black.withValues(alpha: 0.6);
    final borderPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // 匹配缩略图的1px边距
    const margin = 1.0;
    final adjustedHeight = trackHeight - (margin * 2);
    
    // Draw shaded areas with margin to avoid covering thumbnail edges
    canvas.drawRect(Rect.fromLTWH(margin, margin, left - margin, adjustedHeight), shadePaint);
    canvas.drawRect(Rect.fromLTWH(right + margin, margin, size.width - right - margin, adjustedHeight), shadePaint);

    // Draw selection border aligned with thumbnail margins
    canvas.drawRect(
      Rect.fromLTWH(left + margin, margin, right - left - (margin * 2), adjustedHeight), 
      borderPaint
    );
  }

  @override
  bool shouldRepaint(covariant _SelectionPainter oldDelegate) {
    return oldDelegate.left != left || oldDelegate.right != right;
  }
}