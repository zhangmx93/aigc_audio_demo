import 'package:flutter/material.dart';

class VideoSizeControl extends StatelessWidget {
  final double currentWidth;
  final double minWidth;
  final double maxWidth;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onReset;

  const VideoSizeControl({
    super.key,
    required this.currentWidth,
    required this.minWidth,
    required this.maxWidth,
    required this.onIncrease,
    required this.onDecrease,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '视图宽度',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: currentWidth > minWidth ? onDecrease : null,
                  icon: const Icon(Icons.remove),
                  tooltip: '减小宽度',
                ),
                const SizedBox(width: 8),
                Text(
                  '${currentWidth.round()}px',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: currentWidth < maxWidth ? onIncrease : null,
                  icon: const Icon(Icons.add),
                  tooltip: '增加宽度',
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: onReset,
              child: const Text('重置'),
            ),
          ],
        ),
      ),
    );
  }
}