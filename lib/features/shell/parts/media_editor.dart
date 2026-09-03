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
        configs: const ProImageEditorConfigs(
          mainEditor: MainEditorConfigs(
            style: MainEditorStyle(
              background: PlayifyColors.background,
            ),
          ),
          cropRotateEditor: CropRotateEditorConfigs(
            enabled: true,
            canChangeAspectRatio: true,
          ),
          filterEditor: FilterEditorConfigs(
            enabled: true,
          ),
          tuneEditor: TuneEditorConfigs(
            enabled: true,
          ),
          paintEditor: PaintEditorConfigs(
            enabled: true,
          ),
          textEditor: TextEditorConfigs(
            enabled: true,
          ),
          emojiEditor: EmojiEditorConfigs(
            enabled: true,
          ),
          i18n: I18n(
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
