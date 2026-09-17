import 'package:flutter/material.dart';

class SpiceLevelPickerDialog extends StatefulWidget {
  const SpiceLevelPickerDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SpiceLevelPickerDialog(),
    );
  }

  @override
  State<SpiceLevelPickerDialog> createState() => _SpiceLevelPickerDialogState();
}

class _SpiceLevelPickerDialogState extends State<SpiceLevelPickerDialog> {
  static const Color _accentOrange = Color(0xFFFF7A00);
  static const List<String> _options = [
    'Mild',
    'Mild Medium',
    'Medium',
    'Medium Hot',
    'Hot',
    'Extra Hot',
  ];

  String? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select spice level'),
      content: SizedBox(
        width: 360,
        child: RadioGroup<String>(
          groupValue: _selected,
          onChanged: (value) => setState(() => _selected = value),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _options.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final option = _options[index];
              return RadioListTile<String>(
                value: option,
                title: Text(option),
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Not Applicable'),
        ),
        ElevatedButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.of(context).pop(_selected),
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentOrange,
          ),
          child: const Text(
            'Continue',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
