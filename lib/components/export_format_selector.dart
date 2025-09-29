import 'package:flutter/material.dart';
import '../data/export_formats.dart';

class ExportFormatSelector extends StatelessWidget {
  final ExportFormat selectedFormat;
  final ValueChanged<ExportFormat> onChanged;
  final bool enabled;

  const ExportFormatSelector({
    super.key,
    required this.selectedFormat,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: enabled 
              ? [Colors.blue.shade50, Colors.blue.shade100]
              : [Colors.grey.shade200, Colors.grey.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? Colors.blue.shade300 : Colors.grey.shade400,
          width: 1.5,
        ),
        boxShadow: enabled ? [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.file_download_outlined,
            size: 20,
            color: enabled ? Colors.blue.shade700 : Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Text(
            '导出格式:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: enabled ? Colors.blue.shade900 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ExportFormat>(
                value: selectedFormat,
                onChanged: enabled ? (ExportFormat? value) {
                  if (value != null) onChanged(value);
                } : null,
                isDense: true,
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: enabled ? Colors.blue.shade700 : Colors.grey.shade600,
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: enabled ? Colors.blue.shade800 : Colors.grey.shade600,
                ),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(8),
                items: ExportFormats.all.map<DropdownMenuItem<ExportFormat>>((formatData) {
                  return DropdownMenuItem<ExportFormat>(
                    value: formatData.format,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  formatData.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                // Text(
                                //   formatData.description,
                                //   style: TextStyle(
                                //     fontSize: 11,
                                //     color: Colors.grey.shade600,
                                //   ),
                                //   overflow: TextOverflow.ellipsis,
                                // ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}