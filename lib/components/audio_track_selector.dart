import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../data/audio_tracks.dart';

class AudioTrackSelector extends StatelessWidget {
  final AudioTrackType selectedTrackType;
  final String? customAudioPath;
  final ValueChanged<AudioTrackType> onTrackTypeChanged;
  final ValueChanged<String?> onCustomAudioChanged;
  final bool enabled;

  const AudioTrackSelector({
    super.key,
    required this.selectedTrackType,
    required this.customAudioPath,
    required this.onTrackTypeChanged,
    required this.onCustomAudioChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: enabled 
              ? [Colors.purple.shade50, Colors.purple.shade100]
              : [Colors.grey.shade200, Colors.grey.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? Colors.purple.shade300 : Colors.grey.shade400,
          width: 1.5,
        ),
        boxShadow: enabled ? [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.audiotrack,
                size: 20,
                color: enabled ? Colors.purple.shade700 : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                '音轨设置',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: enabled ? Colors.purple.shade900 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...AudioTracks.predefined.map((trackData) {
            final isSelected = selectedTrackType == trackData.type;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: enabled ? () => onTrackTypeChanged(trackData.type) : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Colors.purple.shade100 
                        : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected 
                          ? Colors.purple.shade400 
                          : Colors.purple.shade200,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isSelected ? Colors.purple.shade600 : Colors.grey.shade500,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trackData.label,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isSelected ? Colors.purple.shade800 : Colors.grey.shade800,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              trackData.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (trackData.type == AudioTrackType.custom)
                        IconButton(
                          onPressed: enabled ? _pickAudioFile : null,
                          icon: Icon(
                            Icons.folder_open,
                            color: enabled ? Colors.purple.shade600 : Colors.grey.shade400,
                          ),
                          tooltip: '选择音频文件',
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          
          // Show selected custom audio file
          if (selectedTrackType == AudioTrackType.custom && customAudioPath != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.music_note, color: Colors.green.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '已选择音频文件:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          customAudioPath!.split('/').last,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: enabled ? () => onCustomAudioChanged(null) : null,
                    icon: Icon(Icons.close, color: Colors.red.shade600, size: 18),
                    tooltip: '移除音频文件',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'flac', 'ogg'],
      );
      
      if (result != null && result.files.single.path != null) {
        final audioPath = result.files.single.path!;
        onTrackTypeChanged(AudioTrackType.custom);
        onCustomAudioChanged(audioPath);
      }
    } catch (e) {
      // Handle error silently or show error dialog
    }
  }
}