// lib/features/shell/parts/media_editor.dart
// Full-featured image editor shown after picking a photo.
// Features: crop, rotate, flip, filters, brightness, draw, text, emoji, stickers.
// Uses pro_image_editor package.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../../../core/theme/colors.dart';

/// Open the image editor and return edited bytes, or null if cancelled.
Future<Uint8List?> openMediaEditor(
  BuildContext context,
  Uint8List imageBytes, {
  String? filename,
}) async {
  Uint8List? result;

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ProImageEditor.memory(
        imageBytes,
        callbacks: ProImageEditorCallbacks(
          onImageEditingComplete: (bytes) async {
            result = bytes;
            if (context.mounted) Navigator.pop(context);
          },
          onCloseEditor: () {
            if (context.mounted) Navigator.pop(context);
          },
        ),
        configs: ProImageEditorConfigs(
          mainEditor: MainEditorConfigs(
            style: MainEditorStyle(
              background: PlayifyColors.background,
            ),
          ),
          cropRotateEditor: const CropRotateEditorConfigs(
            enabled: true,
            canChangeAspectRatio: true,
          ),
          filterEditor: const FilterEditorConfigs(
            enabled: true,
          ),
          tuneEditor: const TuneEditorConfigs(
            enabled: true,
          ),
          paintEditor: const PaintEditorConfigs(
            enabled: true,
          ),
          textEditor: const TextEditorConfigs(
            enabled: true,
          ),
          emojiEditor: const EmojiEditorConfigs(
            enabled: true,
          ),
          i18n: const I18n(
            various: I18nVarious(closeEditorWarningTitle: 'Discard changes?'),
            cropRotateEditor: I18nCropRotateEditor(
              bottomNavigationBarText: 'Crop & Rotate',
            ),
            filterEditor: I18nFilterEditor(
              bottomNavigationBarText: 'Filters',
            ),
            tuneEditor: I18nTuneEditor(
              bottomNavigationBarText: 'Adjust',
            ),
            paintEditor: I18nPaintEditor(
              bottomNavigationBarText: 'Draw',
            ),
            textEditor: I18nTextEditor(
              bottomNavigationBarText: 'Text',
            ),
            emojiEditor: I18nEmojiEditor(
              bottomNavigationBarText: 'Emoji',
            ),
          ),
        ),
      ),
      fullscreenDialog: true,
    ),
  );

  return result;
}
