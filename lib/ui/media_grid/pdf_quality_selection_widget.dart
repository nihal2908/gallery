import 'package:flutter/material.dart';

class QualitySelectionWidget extends StatefulWidget {
  final Function(bool keepOriginal, int quality)? onChanged;

  const QualitySelectionWidget({super.key, this.onChanged});

  @override
  _QualitySelectionWidgetState createState() => _QualitySelectionWidgetState();
}

class _QualitySelectionWidgetState extends State<QualitySelectionWidget> {
  bool keepOriginal = false;
  double quality = 1088;

  void notifyParent() {
    if (widget.onChanged != null) {
      widget.onChanged!(keepOriginal, quality.toInt());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: keepOriginal,
              onChanged: (value) {
                setState(() {
                  keepOriginal = value ?? false;
                });
                notifyParent();
              },
            ),
            const Expanded(
              child: Text('Keep Original Image Quality. Large file size!'),
            ),
          ],
        ),

        // const SizedBox(height: 10),

        // OPTION 1: Disable slider (recommended UX)
        Opacity(
          opacity: keepOriginal ? 0.4 : 1,
          child: IgnorePointer(
            ignoring: keepOriginal,
            child: Slider(
              min: 512,
              max: 2048,
              divisions: 8,
              value: quality,
              label:
                  "${quality.round().toString()} × ${quality.round().toString()}",
              onChanged: (value) {
                setState(() {
                  quality = value;
                });
                notifyParent();
              },
            ),
          ),
        ),

        Align(
          alignment: Alignment.center,
          child: Text(
            'Image Quality: ${quality.toInt().toString()} × ${quality.round().toString()}',
          ),
        ),
      ],
    );
  }
}
