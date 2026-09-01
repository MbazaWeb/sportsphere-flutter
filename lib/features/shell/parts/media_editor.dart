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
          onCloseEditor: ({required bool ignoreChanges}) {
            if (context.mounted) Navigator.pop(context);
          },
        ),
        configs: ProImageEditorConfigs(
          mainEditorConfigs: MainEditorConfigs(
            style: MainEditorStyle(
              background: PlayifyColors.background,
              appBarBackground: const Color(0xFF0D1F35),
              appBarForeground: Colors.white,
              bottomBarBackground: const Color(0xFF0D1F35),
              bottomBarForeground: Colors.white,
            ),
          ),
          cropRotateEditorConfigs: const CropRotateEditorConfigs(
            enabled: true,
            canChangeAspectRatio: true,
            initAspectRatio: CropAspectRatios.custom,
          ),
          filterEditorConfigs: const FilterEditorConfigs(
            enabled: true,
          ),
          tuneEditorConfigs: const TuneEditorConfigs(
            enabled: true,
          ),
          paintEditorConfigs: const PaintEditorConfigs(
            enabled: true,
          ),
          textEditorConfigs: const TextEditorConfigs(
            enabled: true,
          ),
          emojiEditorConfigs: const EmojiEditorConfigs(
            enabled: true,
          ),
          stickerEditorConfigs: StickerEditorConfigs(
            enabled: false, // disable until stickers configured
            buildStickers: (setLayer, scrollController) => const SizedBox(),
          ),
          imageGenerationConfigs: const ImageGenerationConfigs(
            outputFormat: OutputFormat.jpg,
            jpegQuality: 88,
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
            paintEditor: I18nPaintingEditor(
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
