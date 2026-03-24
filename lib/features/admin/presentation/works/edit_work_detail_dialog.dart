import 'package:flutter/material.dart' hide ButtonStyle;
import 'package:john_estacio_website/core/constants/app_constants.dart';
import 'package:john_estacio_website/features/works/domain/models/work_model.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:john_estacio_website/core/widgets/rich_text_editor.dart';
import 'package:john_estacio_website/core/utils/markdown_quill_converter.dart';
import 'package:john_estacio_website/theme.dart';
import 'package:john_estacio_website/features/admin/presentation/works/file_uploader_widget.dart';
import 'package:john_estacio_website/features/admin/presentation/works/storage_file_picker_dialog.dart';

class EditWorkDetailDialog extends StatefulWidget {
  final WorkDetail? detail;

  const EditWorkDetailDialog({super.key, this.detail});

  @override
  State<EditWorkDetailDialog> createState() => _EditWorkDetailDialogState();
}

class _EditWorkDetailDialogState extends State<EditWorkDetailDialog> {
  final _formKey = GlobalKey<FormState>();
  late WorkDetail _currentDetail;
  double? _aspectRatio;

  late TextEditingController _buttonTextController;
  late TextEditingController _contentController;
  late quill.QuillController _quillController;
  final List<AudioClip> _audioClips = [];

  @override
  void initState() {
    super.initState();
    _currentDetail = widget.detail ?? WorkDetail.empty();

    // If the existing detail is of type Request, enforce defaults
    if (_currentDetail.detailType == DetailType.request) {
      _currentDetail = _copyWith(
        displayType: DisplayType.button,
        buttonStyle: ButtonStyle.primary,
      );
    }

    _buttonTextController =
        TextEditingController(text: _currentDetail.buttonText);
    _contentController = TextEditingController(
        text: _currentDetail.detailType != DetailType.audio &&
                _currentDetail.detailType != DetailType.richText
            ? _currentDetail.content?.toString()
            : '');

    if (_currentDetail.detailType == DetailType.richText) {
      final content = _currentDetail.content;
      try {
        if (content is Map<String, dynamic>) {
          _quillController = quill.QuillController(
            document: quill.Document.fromJson(content['ops']),
            selection: const TextSelection.collapsed(offset: 0),
          );
        } else if (content is String && content.isNotEmpty) {
          // Seed from string; detect markdown and convert if needed
          final doc = MarkdownQuillConverter.looksLikeMarkdown(content)
              ? MarkdownQuillConverter.toQuillDocument(content)
              : quill.Document()..insert(0, '$content\n');
          _quillController = quill.QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
          );
        } else {
          _quillController = quill.QuillController.basic();
        }
      } catch (_) {
        _quillController = quill.QuillController.basic();
      }
    } else {
      _quillController = quill.QuillController.basic();
    }

    if (_currentDetail.detailType == DetailType.audio &&
        _currentDetail.content is List) {
      _audioClips.addAll(_currentDetail.content.cast<AudioClip>());
    }

    if (_shouldShowImageTools()) {
      _getImageAspectRatio();
    }
  }

  bool _isImageUrlLike(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  bool _shouldShowImageTools() {
    if (_currentDetail.content is! String ||
        (_currentDetail.content as String).isEmpty) {
      return false;
    }
    if (_currentDetail.detailType == DetailType.image) return true;
    if (_currentDetail.detailType == DetailType.link) {
      final url = _currentDetail.content.toString();
      return _isImageUrlLike(url);
    }
    return false;
  }

  String _imagePreviewUrl() {
    // Use proxy only for external links; Firebase Storage links are typically CORS-enabled
    final url = _currentDetail.content?.toString() ?? '';
    if (_currentDetail.detailType == DetailType.link) {
      return '${AppConstants.imageProxyUrl}?url=${Uri.encodeComponent(url)}';
    }
    return url;
  }

  void _getImageAspectRatio() {
    final imageUrl = _imagePreviewUrl();
    final imageStream =
        NetworkImage(imageUrl).resolve(const ImageConfiguration());
    imageStream.addListener(ImageStreamListener((ImageInfo info, bool _) {
      if (mounted) {
        setState(() {
          _aspectRatio = info.image.width / info.image.height;
          if (_currentDetail.width == null) {
            _currentDetail = _copyWith(
              width: info.image.width.toDouble() > 600
                  ? 600
                  : info.image.width.toDouble(),
            );
          }
        });
      }
    }, onError: (dynamic _, __) {
      // Ignore; keep slider hidden if we can't resolve aspect ratio
    }));
  }

  @override
  void dispose() {
    _buttonTextController.dispose();
    _contentController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      dynamic finalContent;
      switch (_currentDetail.detailType) {
        case DetailType.audio:
          finalContent = _audioClips;
          break;
        case DetailType.richText:
          finalContent = {'ops': _quillController.document.toDelta().toJson()};
          break;
        default:
          finalContent = _contentController.text;
      }

      final updatedDetail = _copyWith(
        buttonText: _buttonTextController.text,
        content: finalContent,
      );
      Navigator.of(context).pop(updatedDetail);
    }
  }

  WorkDetail _copyWith({
    String? id,
    int? order,
    DisplayType? displayType,
    ButtonStyle? buttonStyle,
    String? buttonText,
    DetailType? detailType,
    dynamic content,
    bool? isCorrupted,
    bool? isTitleVisible,
    bool? isVisibleDetailTitle,
    double? width,
    String? storagePath,
  }) {
    final newHeight = (width != null && _aspectRatio != null)
        ? width / _aspectRatio!
        : _currentDetail.height;

    return WorkDetail(
      id: id ?? _currentDetail.id,
      order: order ?? _currentDetail.order,
      displayType: displayType ?? _currentDetail.displayType,
      buttonStyle: buttonStyle ?? _currentDetail.buttonStyle,
      buttonText: buttonText ?? _currentDetail.buttonText,
      detailType: detailType ?? _currentDetail.detailType,
      content: content ?? _currentDetail.content,
      isCorrupted: isCorrupted ?? _currentDetail.isCorrupted,
      isTitleVisible: isTitleVisible ?? _currentDetail.isTitleVisible,
      isVisibleDetailTitle:
          isVisibleDetailTitle ?? _currentDetail.isVisibleDetailTitle,
      width: width ?? _currentDetail.width,
      height: newHeight ?? _currentDetail.height,
      storagePath: storagePath ?? _currentDetail.storagePath,
    );
  }

  void _handleTitleVisibilityToggle() {
    final newVisible = !_currentDetail.isTitleVisible;
    setState(() {
      _currentDetail = _copyWith(isTitleVisible: newVisible);

      if (_currentDetail.detailType == DetailType.richText) {
        final title = _buttonTextController.text.trim();
        if (title.isEmpty) return;

        final plain = _quillController.document.toPlainText();
        final firstLine = plain.split('\n').first;

        if (newVisible) {
          if (firstLine != title) {
            _quillController.replaceText(
              0,
              0,
              '$title\n',
              const TextSelection.collapsed(offset: 0),
            );
          }
          final len = title.length;
          try {
            _quillController.updateSelection(
              TextSelection(baseOffset: 0, extentOffset: len),
              quill.ChangeSource.local,
            );
            _quillController.formatSelection(quill.Attribute.h1);
          } catch (_) {
            _quillController.formatText(0, 1, quill.Attribute.h1);
          }
        } else {
          if (firstLine == title) {
            final deleteLen = title.length + 1;
            _quillController.replaceText(
              0,
              deleteLen,
              '',
              const TextSelection.collapsed(offset: 0),
            );
          }
        }
      }
    });
  }

  void _onDetailTypeChanged(DetailType? value) {
    if (value == null) return;

    // If switching TO Rich Text, seed the Quill editor with current content
    if (value == DetailType.richText && _currentDetail.detailType != DetailType.richText) {
      String seed = '';
      if (_currentDetail.detailType == DetailType.audio) {
        if (_audioClips.isNotEmpty) {
          seed = _audioClips.map((c) => '${c.title} - ${c.url}').join('\n');
        }
      } else {
        seed = _contentController.text;
      }

      quill.Document doc;
      if (seed.isNotEmpty && MarkdownQuillConverter.looksLikeMarkdown(seed)) {
        doc = MarkdownQuillConverter.toQuillDocument(seed);
      } else {
        doc = quill.Document()..insert(0, seed.isNotEmpty ? '$seed\n' : '');
      }

      final seededController = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );

      setState(() {
        _quillController = seededController;
        _currentDetail = _copyWith(detailType: value);
      });
      return;
    }

    setState(() {
      // If Request type, force Display As = button and Button Style = primary
      final isRequest = value == DetailType.request;
      final newDisplay = isRequest ? DisplayType.button : _currentDetail.displayType;
      final newButtonStyle = isRequest ? ButtonStyle.primary : _currentDetail.buttonStyle;
      _currentDetail = _copyWith(
        detailType: value,
        displayType: newDisplay,
        buttonStyle: newButtonStyle,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(widget.detail == null ? 'Add Detail' : 'Edit Detail'),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _buttonTextController,
                        style: const TextStyle(color: AppTheme.darkGray),
                        decoration: const InputDecoration(
                          labelText: 'Button/Title Text',
                          filled: true,
                          fillColor: AppTheme.white,
                          labelStyle: TextStyle(color: AppTheme.darkGray),
                          hintStyle: TextStyle(color: AppTheme.darkGray),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8.0)),
                            borderSide: BorderSide(color: AppTheme.lightGray),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8.0)),
                            borderSide: BorderSide(color: AppTheme.lightGray),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8.0)),
                            borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
                          ),
                        ),
                        validator: (value) => value!.isEmpty ? 'This field is required' : null,
                      ),
                    ),
                    if (_currentDetail.detailType != DetailType.link) ...[
                      const SizedBox(width: 12),
                      Tooltip(
                        message: _currentDetail.isTitleVisible ? 'Hide title' : 'Show title',
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.white,
                            side: const BorderSide(color: AppTheme.lightGray),
                          ),
                          onPressed: _handleTitleVisibilityToggle,
                          icon: Icon(
                            _currentDetail.isTitleVisible ? Icons.visibility : Icons.visibility_off,
                            color: AppTheme.darkGray,
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<DetailType>(
                        value: _currentDetail.detailType,
                        dropdownColor: AppTheme.white,
                        style: const TextStyle(color: AppTheme.darkGray),
                        decoration: const InputDecoration(
                          labelText: 'Detail Type',
                          filled: true,
                          fillColor: AppTheme.white,
                          labelStyle: TextStyle(color: AppTheme.darkGray),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: AppTheme.lightGray),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppTheme.lightGray),
                          ),
                        ),
                        icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.lightGray),
                        onChanged: _onDetailTypeChanged,
                        items: DetailType.values
                            .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type.name, style: const TextStyle(color: AppTheme.darkGray)),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<DisplayType>(
                        value: _currentDetail.displayType,
                        dropdownColor: AppTheme.white,
                        style: const TextStyle(color: AppTheme.darkGray),
                        decoration: const InputDecoration(
                          labelText: 'Display As',
                          filled: true,
                          fillColor: AppTheme.white,
                          labelStyle: TextStyle(color: AppTheme.darkGray),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: AppTheme.lightGray),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppTheme.lightGray),
                          ),
                        ),
                        icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.lightGray),
                        onChanged: (_currentDetail.detailType == DetailType.request)
                            ? null
                            : (value) => setState(() => _currentDetail = _copyWith(displayType: value)),
                        items: DisplayType.values
                            .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type.name, style: const TextStyle(color: AppTheme.darkGray)),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildButtonStyleDropdown(),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                // Inline-only: toggle for showing inline detail title
                if (_currentDetail.displayType == DisplayType.inline)
                  SwitchListTile.adaptive(
                    value: _currentDetail.isVisibleDetailTitle ?? false,
                    onChanged: (val) {
                      setState(() {
                        _currentDetail = _copyWith(isVisibleDetailTitle: val);
                      });
                    },
                    title: const Text(
                      'Show inline detail title',
                      style: TextStyle(color: AppTheme.darkGray),
                    ),
                    subtitle: const Text(
                      'Controls visibility of the title above inline content',
                      style: TextStyle(color: AppTheme.darkGray),
                    ),
                    activeColor: AppTheme.primaryOrange,
                    tileColor: AppTheme.white,
                    contentPadding: EdgeInsets.zero,
                  ),

                const SizedBox(height: 16),
                _buildContentField(),

                if (_shouldShowImageTools()) ...[
                  const Divider(height: 32),
                  const Text('Image Preview & Resizing',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (_aspectRatio == null)
                    const Center(child: CircularProgressIndicator())
                  else
                    _buildResizableImagePreview(),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Widget _buildContentField() {
    switch (_currentDetail.detailType) {
      case DetailType.audio:
        return _buildAudioContentField();
      case DetailType.richText:
        return _buildRichTextContentField();
      case DetailType.request:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'This button will take users to the Request Score(s) page. No additional content needed.',
            style: TextStyle(color: AppTheme.darkGray),
          ),
        );
      case DetailType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _contentController,
              style: const TextStyle(color: AppTheme.darkGray),
              decoration: const InputDecoration(
                labelText: 'Image URL (auto-filled on upload)',
                filled: true,
                fillColor: AppTheme.white,
                labelStyle: TextStyle(color: AppTheme.darkGray),
                hintStyle: TextStyle(color: AppTheme.darkGray),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8.0)),
                  borderSide: BorderSide(color: AppTheme.lightGray),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8.0)),
                  borderSide: BorderSide(color: AppTheme.lightGray),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8.0)),
                  borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
                ),
              ),
              validator: _contentValidator,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(backgroundColor: AppTheme.white),
                  onPressed: () async {
                    final res = await showDialog<StorageFilePickerResult>(
                      context: context,
                      builder: (_) => const StorageFilePickerDialog(kind: PickerFileKind.image),
                    );
                    if (res != null) {
                      setState(() {
                        _contentController.text = res.url;
                        _currentDetail = _copyWith(content: res.url, storagePath: res.ref.fullPath);
                      });
                      _getImageAspectRatio();
                    }
                  },
                  icon: const Icon(Icons.photo_library, color: AppTheme.darkGray),
                  label: const Text('Choose from Stored Images', style: TextStyle(color: AppTheme.darkGray)),
                ),
                const SizedBox(width: 12),
                Text('or upload a new image', style: const TextStyle(color: AppTheme.darkGray)),
              ],
            ),
            const SizedBox(height: 12),
            FileUploaderWidget(
              initialUrl: _currentDetail.content is String ? _currentDetail.content : null,
              onUrlChanged: (url) {
                setState(() {
                  _contentController.text = url;
                  _currentDetail = _copyWith(content: url);
                });
                _getImageAspectRatio();
              },
              fileTypeDescription: 'Image File (.jpg, .jpeg, .png, .gif, .webp)',
              showUrlField: false,
              allowedExtensions: const ['jpg', 'jpeg', 'png', 'gif', 'webp'],
              allowedMime: const [
                'image/jpeg',
                'image/png',
                'image/gif',
                'image/webp',
                'image/bmp',
                'image/tiff',
                'image/svg+xml',
              ],
            ),
          ],
        );
      default:
        // Specialized PDF input with storage chooser
        if (_currentDetail.detailType == DetailType.pdf) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _contentController,
                style: const TextStyle(color: AppTheme.darkGray),
                decoration: const InputDecoration(
                  labelText: 'PDF URL (auto-filled on upload or pick)',
                  filled: true,
                  fillColor: AppTheme.white,
                  labelStyle: TextStyle(color: AppTheme.darkGray),
                  hintStyle: TextStyle(color: AppTheme.darkGray),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    borderSide: BorderSide(color: AppTheme.lightGray),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    borderSide: BorderSide(color: AppTheme.lightGray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
                  ),
                ),
                validator: _contentValidator,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(backgroundColor: AppTheme.white),
                onPressed: () async {
                  final res = await showDialog<StorageFilePickerResult>(
                    context: context,
                    builder: (_) => const StorageFilePickerDialog(kind: PickerFileKind.pdf),
                  );
                  if (res != null) {
                    setState(() {
                      _contentController.text = res.url;
                      _currentDetail = _copyWith(content: res.url, storagePath: res.ref.fullPath);
                    });
                  }
                },
                icon: const Icon(Icons.picture_as_pdf, color: AppTheme.darkGray),
                label: const Text('Choose from Stored PDFs', style: TextStyle(color: AppTheme.darkGray)),
              ),
              const SizedBox(height: 12),
              FileUploaderWidget(
                initialUrl: _currentDetail.content is String ? _currentDetail.content : null,
                onUrlChanged: (url) {
                  setState(() {
                    _contentController.text = url;
                    _currentDetail = _copyWith(content: url);
                  });
                },
                fileTypeDescription: 'PDF File (.pdf)',
                showUrlField: false,
                allowedExtensions: const ['pdf'],
                allowedMime: const ['application/pdf'],
              ),
            ],
          );
        }
        return TextFormField(
          controller: _contentController,
          style: const TextStyle(color: AppTheme.darkGray),
          decoration: InputDecoration(
            labelText: _getContentFieldLabel(),
            filled: true,
            fillColor: AppTheme.white,
            labelStyle: const TextStyle(color: AppTheme.darkGray),
            hintStyle: const TextStyle(color: AppTheme.darkGray),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8.0)),
              borderSide: BorderSide(color: AppTheme.lightGray),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8.0)),
              borderSide: BorderSide(color: AppTheme.lightGray),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8.0)),
              borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
            ),
          ),
          validator: _contentValidator,
        );
    }
  }
  
  String _getContentFieldLabel() {
    switch (_currentDetail.detailType) {
      case DetailType.link:
        return 'Link Address';
      case DetailType.embed:
        return '</> Paste embed code here';
      case DetailType.request:
        return 'N/A';
      case DetailType.image:
        return 'Image URL';
      default:
        return '${_currentDetail.detailType.name} Content (URL/Embed)';
    }
  }

  String? _contentValidator(String? value) {
    if (_currentDetail.detailType == DetailType.request) {
      return null; // no content required
    }
    if (value == null || value.isEmpty) {
      return 'This field is required';
    }
    if (_currentDetail.detailType == DetailType.link) {
      // Accept standard web URLs and Firebase Storage URLs (including gs:// and percent-encoded paths)
      final urlRegex = RegExp(r'^(?:(?:https?|gs):\/\/)[^\s]+$');
      if (!urlRegex.hasMatch(value.trim())) {
        return 'Please enter a valid URL';
      }
    }
    if (_currentDetail.detailType == DetailType.embed) {
      final embedRegex = RegExp(r'<iframe[\s\S]*src="[^"]+"[\s\S]*>[\s\S]*<\/iframe>');
      if (!embedRegex.hasMatch(value)) {
        return 'Please paste a valid HTML embed code (e.g., from YouTube or Vimeo)';
      }
    }
    return null;
  }

  Widget _buildButtonStyleDropdown() {
    if (_currentDetail.displayType != DisplayType.button) {
      return const SizedBox.shrink();
    }

    final items = ButtonStyle.values.map((style) {
      return DropdownMenuItem<ButtonStyle>(
        value: style,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: _buildButtonPreview(style),
        ),
      );
    }).toList();

    final effectiveValue = _currentDetail.buttonStyle;

    return DropdownButtonFormField<ButtonStyle>(
      value: effectiveValue,
      dropdownColor: AppTheme.white,
      style: const TextStyle(color: AppTheme.darkGray),
      decoration: const InputDecoration(
        labelText: 'Button Style',
        filled: true,
        fillColor: AppTheme.white,
        labelStyle: TextStyle(color: AppTheme.darkGray),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.lightGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.lightGray),
        ),
      ),
      icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.lightGray),
      onChanged: (_currentDetail.detailType == DetailType.request)
          ? null
          : (value) => setState(() => _currentDetail = _copyWith(buttonStyle: value)),
      items: items,
      selectedItemBuilder: (context) => ButtonStyle.values
          .map((style) => Align(
                alignment: Alignment.centerLeft,
                child: Text(style.name, style: const TextStyle(color: AppTheme.darkGray)),
              ))
          .toList(),
    );
  }

  Widget _buildButtonPreview(ButtonStyle style) {
    final label = style.name;
    final isPrimary = style == ButtonStyle.primary;

    // Match WorkCard button visuals
    final background = isPrimary ? AppTheme.primaryOrange : AppTheme.darkGray;
    final foreground = isPrimary ? AppTheme.black : AppTheme.primaryOrange;
    final borderColor = isPrimary ? AppTheme.black : AppTheme.primaryOrange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Center(
        child: Text(
          label.toUpperCase(),
          style: AppTheme.theme.textTheme.labelLarge?.copyWith(color: foreground),
        ),
      ),
    );
  }

  Widget _buildAudioContentField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Audio Clips',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkGray),
        ),
        const SizedBox(height: 8),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex -= 1;
              final item = _audioClips.removeAt(oldIndex);
              _audioClips.insert(newIndex, item);
            });
          },
          // Keep the dragged proxy white instead of dark/black
          proxyDecorator: (child, index, animation) {
            return Material(
              color: AppTheme.white,
              elevation: 6,
              shadowColor: Colors.black,
              surfaceTintColor: Colors.transparent,
              child: child,
            );
          },
          children: [
            for (int i = 0; i < _audioClips.length; i++)
              Material(
                key: ValueKey('audio_clip_${i}_${_audioClips[i].url}'),
                color: AppTheme.white,
                child: ListTile(
                  leading: ReorderableDragStartListener(
                    index: i,
                    child: const Icon(Icons.drag_indicator, color: AppTheme.darkGray),
                  ),
                  title: Text(
                    _audioClips[i].title,
                    style: const TextStyle(color: AppTheme.darkGray),
                  ),
                  subtitle: Text(
                    _audioClips[i].url,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.darkGray),
                  ),
                  onTap: () => _editAudioClip(i),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit, color: AppTheme.darkGray),
                        onPressed: () => _editAudioClip(i),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => setState(() => _audioClips.removeAt(i)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        TextButton.icon(
          icon: const Icon(Icons.add, color: AppTheme.darkGray),
          label: const Text('Add Audio Clip', style: TextStyle(color: AppTheme.darkGray)),
          onPressed: _addAudioClip,
        ),
      ],
    );
  }

  Future<void> _addAudioClip() async {
    final result = await _showAudioClipDialog();
    if (result != null) {
      setState(() => _audioClips.add(result));
    }
  }

  Future<void> _editAudioClip(int index) async {
    if (index < 0 || index >= _audioClips.length) return;
    final existing = _audioClips[index];
    final updated = await _showAudioClipDialog(initial: existing);
    if (updated != null) {
      setState(() => _audioClips[index] = existing.copyWith(
            title: updated.title,
            url: updated.url,
            // prefer newly selected storage path if provided
            fileId: updated.fileId.isNotEmpty ? updated.fileId : existing.fileId,
          ));
    }
  }

  Future<AudioClip?> _showAudioClipDialog({AudioClip? initial}) async {
    return showDialog<AudioClip>(
      context: context,
      builder: (context) {
        final formKey = GlobalKey<FormState>();
        final titleController = TextEditingController(text: initial?.title ?? 'Audio Clip');
        final urlController = TextEditingController(text: initial?.url ?? '');
        String? selectedStoragePath = initial?.fileId.isNotEmpty == true ? initial!.fileId : null;

        return AlertDialog(
          backgroundColor: AppTheme.white,
          title: Text(
            initial == null ? 'Add Audio Clip' : 'Edit Audio Clip',
            style: const TextStyle(color: AppTheme.darkGray),
          ),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title (required)
                    TextFormField(
                      controller: titleController,
                      style: const TextStyle(color: AppTheme.darkGray),
                      decoration: const InputDecoration(
                        labelText: 'Audio Clip Title',
                        hintText: 'Audio Clip',
                        filled: true,
                        fillColor: AppTheme.white,
                        labelStyle: TextStyle(color: AppTheme.darkGray),
                        hintStyle: TextStyle(color: AppTheme.darkGray),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8.0)),
                          borderSide: BorderSide(color: AppTheme.lightGray),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8.0)),
                          borderSide: BorderSide(color: AppTheme.lightGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8.0)),
                          borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                    ),

                    const SizedBox(height: 12),

                    // URL (required)
                    TextFormField(
                      controller: urlController,
                      style: const TextStyle(color: AppTheme.darkGray),
                      decoration: const InputDecoration(
                        labelText: 'Audio File URL',
                        hintText: 'Paste Firebase Storage URL or upload below',
                        filled: true,
                        fillColor: AppTheme.white,
                        labelStyle: TextStyle(color: AppTheme.darkGray),
                        hintStyle: TextStyle(color: AppTheme.darkGray),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8.0)),
                          borderSide: BorderSide(color: AppTheme.lightGray),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8.0)),
                          borderSide: BorderSide(color: AppTheme.lightGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8.0)),
                          borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Audio file URL is required' : null,
                    ),

                    const SizedBox(height: 12),

                    // Choose from stored audio files
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(backgroundColor: AppTheme.white),
                      onPressed: () async {
                        final res = await showDialog<StorageFilePickerResult>(
                          context: context,
                          builder: (_) => const StorageFilePickerDialog(kind: PickerFileKind.audio),
                        );
                        if (res != null) {
                          titleController.text = res.titleOrName.isNotEmpty ? res.titleOrName : titleController.text; urlController.text = res.url; selectedStoragePath = res.ref.fullPath;
                          urlController.text = res.url;
                        }
                      },
                      icon: const Icon(Icons.library_music, color: AppTheme.darkGray),
                      label: const Text('Choose from Stored Audio', style: TextStyle(color: AppTheme.darkGray)),
                    ),

                    const SizedBox(height: 12),

                    // Drag & drop / local upload (audio only)
                    FileUploaderWidget(
                      initialUrl: initial?.url,
                      onUrlChanged: (url) {
                        urlController.text = url;
                      },
                      fileTypeDescription: 'Audio File (.mp3, .wav, .m4a)',
                      showUrlField: false,
                      allowedExtensions: const ['mp3', 'wav', 'm4a'],
                      allowedMime: const [
                        'audio/mpeg',
                        'audio/wav',
                        'audio/mp4',
                        'audio/x-m4a',
                        'audio/aac',
                        'audio/ogg',
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.of(context).pop(
                  AudioClip(
                    fileId: (selectedStoragePath ?? initial?.fileId ?? '').trim(),
                    title: titleController.text.trim(),
                    url: urlController.text.trim(),
                  ),
                );
              },
              child: Text(initial == null ? 'Add' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRichTextContentField() {
    return AppRichTextEditor(
      controller: _quillController,
      height: 300,
    );
  }

  Widget _buildResizableImagePreview() {
    final displayWidth = _currentDetail.width ?? 300;
    final displayHeight = (displayWidth / (_aspectRatio ?? 1)).clamp(50, 2000).toDouble();

    return Column(
      children: [
        Center(
          child: Stack(
            children: [
              Container(
                width: displayWidth,
                height: displayHeight,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.lightGray),
                  borderRadius: BorderRadius.circular(4),
                ),
                clipBehavior: Clip.hardEdge,
                child: Image.network(
                  _imagePreviewUrl(),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Text('Could not load image.'));
                  },
                ),
              ),
              // Bottom-right resize handle
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanUpdate: (details) {
                    // Increase width by horizontal delta; keep bounds
                    final newWidth = (displayWidth + details.delta.dx).clamp(100, 1000).toDouble();
                    setState(() {
                      _currentDetail = _copyWith(width: newWidth);
                    });
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeUpLeftDownRight,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange,
                        border: Border.all(color: AppTheme.black),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                        ),
                      ),
                      child: const Icon(Icons.drag_handle, size: 14, color: AppTheme.black),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Slider(
          value: displayWidth,
          min: 100,
          max: 1000,
          divisions: 180,
          label: displayWidth.round().toString(),
          onChanged: (value) {
            setState(() {
              _currentDetail = _copyWith(width: value);
            });
          },
        ),
        Center(child: Text('Display Width: ${displayWidth.round()}px')),
      ],
    );
  }
}
