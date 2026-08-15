import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/post_limits.dart';
import '../../models/post.dart';
import '../../models/post_draft.dart';
import '../../widgets/app_app_bar.dart';
import '../../widgets/image_overlay.dart';
import '../../models/upload_result.dart';
import '../../services/api.dart';
import '../../services/session_service.dart';
import '../../services/storage.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/moderation_feedback.dart';
import '../account/register_page.dart';
import '../settings/settings_navigation.dart';

class PostCreatePage extends StatefulWidget {
  const PostCreatePage({super.key});

  @override
  State<PostCreatePage> createState() => _PostCreatePageState();
}

class _PickedFile {
  final String path;
  final String name;
  final int bytes;

  const _PickedFile({
    required this.path,
    required this.name,
    required this.bytes,
  });
}

class _PostCreatePageState extends State<PostCreatePage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _titleFocus = FocusNode();
  final _contentFocus = FocusNode();

  final List<_PickedFile> _images = [];
  List<GlobalKey> _previewKeys = [];
  _PickedFile? _attachment;
  final List<UploadResult> _uploadedImages = [];
  UploadResult? _uploadedAttachment;

  bool _titleState = false;
  bool _fileState = true;
  bool _uploading = false;
  bool _submitting = false;
  String? _errorMessage;
  Color? _errorColor;
  bool _hasAuthor = false;

  List<UploadResult> get _uploaded => [
    ..._uploadedImages,
    if (_uploadedAttachment != null) _uploadedAttachment!,
  ];

  /// 优先用资料里的 user_display_id，没有再回退本地昵称
  String get _userName {
    final display = PostStorage.getDisplayName()?.trim();
    if (display != null && display.isNotEmpty) return display;
    return PostStorage.getUserName();
  }

  @override
  void initState() {
    super.initState();
    SessionService.instance.ensureSession();
    _titleController.addListener(() {
      final v = _titleController.text.trim().isNotEmpty;
      if (v != _titleState && mounted) setState(() => _titleState = v);
    });
    _contentController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Timer? _errorTimer;

  void _setError(String? msg, {Color color = Colors.transparent}) {
    _errorTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _errorMessage = msg;
      _errorColor = color == Colors.transparent ? null : color;
    });
    if (msg != null) {
      _errorTimer = Timer(
        Duration(milliseconds: AppDimens.postCreateErrorDismissMs),
        () {
          if (mounted) {
            setState(() {
              _errorMessage = null;
              _errorColor = null;
            });
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    _titleFocus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  // ---- 上传文件（合并按钮）----

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'gif',
        'asc',
        'txt',
        'log',
        'conf',
        'nfo',
        'me',
        'tsv',
        'ics',
        'vcs',
        'vcf',
        'c',
        'h',
        'cpp',
        'cxx',
        'py',
        'java',
        'prel',
        'pl',
        'lua',
        'yaml',
        'yml',
        'kt',
      ],
      withData: false,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final pickedImages = <_PickedFile>[];
    _PickedFile? pickedAttachment;
    bool hasUnknown = false;

    for (final f in result.files) {
      final path = f.path;
      final name = f.name;
      if (path == null) continue;
      final ext = name.split('.').last.toLowerCase();
      if (['jpg', 'jpeg', 'png', 'gif'].contains(ext)) {
        pickedImages.add(_PickedFile(path: path, name: name, bytes: f.size));
      } else if ([
        'asc',
        'txt',
        'log',
        'conf',
        'nfo',
        'me',
        'tsv',
        'ics',
        'vcs',
        'vcf',
        'c',
        'h',
        'cpp',
        'cxx',
        'py',
        'java',
        'prel',
        'pl',
        'lua',
        'yaml',
        'yml',
        'kt',
      ].contains(ext)) {
        if (pickedAttachment != null) {
          hasUnknown = true; // 多个附件 — 只保留第一个
        } else {
          pickedAttachment = _PickedFile(path: path, name: name, bytes: f.size);
        }
      } else {
        hasUnknown = true;
      }
    }

    if (pickedImages.isEmpty && pickedAttachment == null) {
      if (hasUnknown) _setError('不支持的文件类型');
      return;
    }

    // 校验图片
    final totalImages = pickedImages.length + _images.length;
    if (totalImages > PostLimits.imageMaxCount) {
      _setError('!上传的图像过多，上限为12张');
      return;
    }
    final currentSize = _images.fold<double>(0, (s, e) => s + e.bytes);
    final newImgSize = pickedImages.fold<double>(0, (s, e) => s + e.bytes);
    if ((currentSize + newImgSize) / 1024 / 1024 > PostLimits.imageMaxTotalMb) {
      _setError('!图片总大小超过8MB');
      return;
    }

    // 校验附件
    if (pickedAttachment != null &&
        pickedAttachment.bytes / 1024 / 1024 > PostLimits.attachmentMaxMb) {
      _setError('附件不能超过 3.5MB');
      return;
    }

    setState(() {
      _images.addAll(pickedImages);
      if (pickedAttachment != null) {
        _attachment = pickedAttachment;
        _uploadedAttachment = null;
      }
      _fileState = false;
      _uploading = true;
      _errorMessage = null;
    });

    // 上传不带 session；署名才带 user_id
    final userId = _hasAuthor ? _userName : null;

    // 并行上传
    final futures = <Future<UploadResult?>>[];
    for (final img in pickedImages) {
      futures.add(
        ApiService.uploadFile(
          PostUploadType.image,
          File(img.path),
          userId: userId,
        ),
      );
    }
    if (pickedAttachment != null) {
      futures.add(
        ApiService.uploadFile(
          PostUploadType.attachment,
          File(pickedAttachment.path),
          userId: userId,
        ),
      );
    }

    final results = await Future.wait(futures);
    if (!mounted) return;

    final failed = results.any((e) => e == null);
    if (failed) {
      setState(() {
        _fileState = false;
        _uploading = false;
      });
      _setError(getModerationMessage(ApiService.lastError ?? '上传失败，请重试'));
      return;
    }

    final all = results.whereType<UploadResult>();
    setState(() {
      for (final r in all) {
        if (r.type == PostUploadType.image) {
          _uploadedImages.add(r);
        } else {
          _uploadedAttachment = r;
        }
      }
      _fileState = true;
      _uploading = false;
    });
  }

  void _removeImage(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      final removed = _images.removeAt(index);
      _uploadedImages.removeWhere((r) => r.filename == removed.name);
      // 同步清理 previewKeys
      if (_previewKeys.length == _images.length + 1) {
        _previewKeys.removeAt(index);
      } else {
        _previewKeys = List.generate(_images.length, (_) => GlobalKey());
      }
      if (_images.isEmpty && _attachment == null) {
        _fileState = true;
      }
    });
  }

  void _removeAttachment() {
    HapticFeedback.lightImpact();
    setState(() {
      _attachment = null;
      _uploadedAttachment = null;
      if (_images.isEmpty) _fileState = true;
    });
  }

  void _clearAll() {
    HapticFeedback.lightImpact();
    setState(() {
      _images.clear();
      _attachment = null;
      _uploadedImages.clear();
      _uploadedAttachment = null;
      _previewKeys = [];
      _fileState = true;
      _errorMessage = null;
    });
  }

  void _toggleAuthor() {
    HapticFeedback.lightImpact();
    setState(() {
      _hasAuthor = !_hasAuthor;
    });
    _errorTimer?.cancel();
    final msg = _hasAuthor ? '开启署名' : '关闭署名';
    if (mounted) {
      setState(() {
        _errorMessage = msg;
        _errorColor = Theme.of(
          context,
        ).extension<AppColors>()!.postCreate.bottomHintText;
      });
    }
    _errorTimer = Timer(
      Duration(milliseconds: AppDimens.postCreateToastDismissMs),
      () {
        if (mounted) {
          setState(() {
            _errorMessage = null;
            _errorColor = null;
          });
        }
      },
    );
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _setError('标题不能为空');
      return;
    }
    if (!_titleState || !_fileState || _uploading || _submitting) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    // 发帖 body 不带 session；署名才附加 user_id / author
    final userId = _hasAuthor ? _userName : null;
    final draft = PostDraft(
      title: title,
      content: _contentController.text,
      author: userId ?? '',
      isAnonymous: !_hasAuthor,
      uploaded: _uploaded,
      userId: userId,
    );

    final post = await ApiService.createPost(draft);
    if (!mounted) return;

    setState(() => _submitting = false);
    if (post == null) {
      _setError(getModerationMessage(ApiService.lastError ?? '发布失败'));
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(context, true);
  }

  void _onTapBlank() {
    _titleFocus.unfocus();
    _contentFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final canSubmit = _titleState && _fileState && !_uploading && !_submitting;
    final hasFiles = _images.isNotEmpty || _attachment != null;
    final registered = PostStorage.isRegistered();

    return PopScope(
      canPop: ImageOverlay.currentEntry == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (ImageOverlay.currentEntry != null) {
          ImageOverlay.closeCurrent();
        }
      },
      child: AppScaffold(
        title: '',
        onBack: () => Navigator.pop(context),
        trailing: Padding(
          padding: EdgeInsets.only(
            right: AppDimens.postCreateSubmitMarginRight,
          ),
          child: _submitButton(canSubmit),
        ),
        backgroundColor: colors.postCreate.pageBg,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _onTapBlank,
          child: ListView(
            padding: EdgeInsets.symmetric(
              vertical: AppDimens.postCreatePagePadding,
            ),
            children: [
              // 输入区
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppDimens.postCreatePagePadding,
                ),
                child: _inputCard(colors, registered),
              ),
              SizedBox(height: AppDimens.postCreateSectionGap),
              // 预览区
              if (hasFiles)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppDimens.postCreatePagePadding,
                  ),
                  child: _previewArea(colors),
                ),
              if (hasFiles)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppDimens.postCreatePagePadding,
                  ),
                  child: Container(
                    height: AppDimens.postCreatePreviewDividerHeight,
                    color: colors.postCreate.previewDivider,
                  ),
                ),
              SizedBox(height: AppDimens.postCreatePreviewGap),
              // 按钮行
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppDimens.postCreateButtonRowPaddingH,
                ),
                child: _buttonRow(colors, hasFiles, registered),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _error(colors),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _error(AppColors colors) {
    return Center(
      child: Text(
        _errorMessage!,
        style: TextStyle(
          color: _errorColor ?? colors.postCreate.errorText,
          fontSize: 14,
        ),
      ),
    );
  }

  // ---- 输入区 ----

  Widget _inputCard(AppColors colors, bool registered) {
    return Container(
      decoration: BoxDecoration(
        color: colors.postCreate.fieldBg,
        borderRadius: BorderRadius.circular(AppDimens.postCreateInputRadius),
        border: AppDimens.postCreateInputBorderWidth > 0
            ? Border.all(
                color: colors.postCreate.divider,
                width: AppDimens.postCreateInputBorderWidth,
              )
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _titleField(colors, registered),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppDimens.postCreateDividerIndent,
            ),
            child: Container(
              height: AppDimens.postCreateDividerThickness,
              color: colors.postCreate.divider,
            ),
          ),
          _contentField(colors, registered),
        ],
      ),
    );
  }

  Widget _titleField(AppColors colors, bool registered) {
    return registered
        ? TextField(
            controller: _titleController,
            focusNode: _titleFocus,
            cursorColor: colors.common.onSurface,
            style: TextStyle(
              fontSize: AppDimens.postCreateLabelFontSizeLarge,
              color: colors.common.onSurface,
            ),
            decoration: InputDecoration(
              labelText: '标题',
              hintText: '请输入标题',
              labelStyle: TextStyle(color: colors.postCreate.titleLabelFloat),
              hintStyle: TextStyle(
                color: colors.postCreate.titleLabelRest.withValues(alpha: 0.6),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppDimens.postCreateInputPaddingH,
                vertical: AppDimens.postCreateInputPaddingV + 8,
              ),
            ),
          )
        : _loginPrompt(colors, '请注册后发布');
  }

  Widget _contentField(AppColors colors, bool registered) {
    return registered
        ? TextField(
            controller: _contentController,
            focusNode: _contentFocus,
            cursorColor: colors.common.onSurface,
            keyboardType: TextInputType.multiline,
            minLines: 5,
            maxLines: 12,
            textAlignVertical: TextAlignVertical.top,
            style: TextStyle(
              fontSize: AppDimens.postCreateContentLabelFontSizeLarge,
              color: colors.common.onSurface,
              height: 1.4,
            ),
            decoration: InputDecoration(
              labelText: '内容',
              hintText: '请输入内容...',
              labelStyle: TextStyle(color: colors.postCreate.contentLabelFloat),
              hintStyle: TextStyle(
                color: colors.postCreate.contentLabelRest.withValues(
                  alpha: 0.6,
                ),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppDimens.postCreateInputPaddingH,
                vertical: AppDimens.postCreateInputPaddingV + 8,
              ),
            ),
          )
        : _loginPrompt(colors, '目前未绑定账号，请注册');
  }

  Widget _loginPrompt(AppColors colors, String text) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(bottomUpRoute(const RegisterPage()));
      },
      child: Container(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(
          horizontal: AppDimens.postCreateInputPaddingH,
          vertical: AppDimens.postCreateInputPaddingV + 16,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: AppDimens.postCreateLabelFontSizeLarge,
            color: colors.postCreate.titleLabelRest.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  // ---- 预览区 ----

  Widget _previewArea(AppColors colors) {
    if (_images.isEmpty && _attachment == null) return const SizedBox.shrink();
    final widgets = <Widget>[];
    if (_images.isNotEmpty) {
      if (_previewKeys.length != _images.length) {
        _previewKeys = List.generate(_images.length, (_) => GlobalKey());
      }
      widgets.add(
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: _images.asMap().entries.map((entry) {
            final index = entry.key;
            final img = entry.value;
            return _PreviewThumb(
              key: _previewKeys[index],
              path: img.path,
              onRemove: () => _removeImage(index),
              onTap: () => _openImageOverlay(index),
            );
          }).toList(),
        ),
      );
    }
    if (_attachment != null) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              const Icon(Icons.description_outlined, size: 18),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _attachment!.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.common.secondary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _removeAttachment,
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: colors.common.secondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: AppDimens.postCreatePreviewGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }

  void _openImageOverlay(int index) {
    if (_images.isEmpty || ImageOverlay.currentEntry != null) return;
    final imageList = _images
        .map((img) => PostImage(fileName: img.name))
        .toList();
    final rects = <Rect?>[];
    for (final key in _previewKeys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) {
        rects.add(null);
        continue;
      }
      final offset = box.localToGlobal(Offset.zero);
      final size = box.size;
      rects.add(Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height));
    }
    while (rects.length <= index) {
      rects.add(null);
    }
    // 本地图片：缓存到 Hive 缩略图，使 ImageOverlay 可以直接找到
    final thumbs = <Uint8List?>[];
    for (final img in _images) {
      final bytes = PostStorage.getThumbnail(img.name)?.bytes;
      if (bytes != null) {
        thumbs.add(bytes);
      } else {
        // 从本地文件读取并缓存
        final fileBytes = File(img.path).readAsBytesSync();
        PostStorage.saveThumbnail(
          img.name,
          ThumbnailData(bytes: fileBytes, width: 0, height: 0),
        );
        thumbs.add(fileBytes);
      }
    }
    final overlay = Overlay.of(context);
    ImageOverlay.currentEntry = OverlayEntry(
      builder: (_) {
        return ImageOverlay(
          images: imageList,
          initialIndex: index,
          thumbRects: rects,
          thumbnails: thumbs,
        );
      },
    );
    overlay.insert(ImageOverlay.currentEntry!);
  }

  // ---- 按钮行 ----

  Widget _buttonRow(AppColors colors, bool hasFiles, bool registered) {
    return Row(
      children: [
        if (registered)
          _iconOnlyButton(
            icon: Icons.upload_file,
            onTap: _uploading ? null : _pickFiles,
            iconColor: colors.postCreate.uploadBtnIcon,
            fillColor: colors.postCreate.fieldBg,
            borderColor: colors.postCreate.uploadBtnBorder,
          ),
        if (registered) SizedBox(width: AppDimens.postCreateActionRowGap),
        if (hasFiles)
          _iconOnlyButton(
            icon: Icons.delete_outline,
            onTap: _clearAll,
            iconColor: colors.postCreate.deleteBtnIcon,
            fillColor: colors.postCreate.fieldBg,
            borderColor: colors.postCreate.deleteBtnBorder,
          ),
        if (hasFiles) SizedBox(width: AppDimens.postCreateActionRowGap),
        const Spacer(),
        _iconOnlyButton(
          icon: _hasAuthor ? Icons.person : Icons.person_outline,
          onTap: _toggleAuthor,
          iconColor: _hasAuthor
              ? colors.postCreate.authorActiveIcon
              : colors.postCreate.authorIcon,
          fillColor: _hasAuthor
              ? colors.postCreate.authorActiveFill
              : colors.postCreate.fieldBg,
          borderColor: _hasAuthor
              ? colors.postCreate.authorActiveFill
              : colors.postCreate.authorBorder,
        ),
      ],
    );
  }

  Widget _iconOnlyButton({
    required IconData icon,
    required VoidCallback? onTap,
    required Color iconColor,
    required Color fillColor,
    required Color borderColor,
    double? size,
    double? radius,
    double? borderWidth,
    double? iconSize,
  }) {
    final w = size ?? AppDimens.postCreateActionButtonSize;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: w,
        height: w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            radius ?? AppDimens.postCreateActionButtonRadius,
          ),
          color: fillColor,
          border: Border.all(
            color: borderColor,
            width: borderWidth ?? AppDimens.postCreateActionButtonBorderWidth,
          ),
        ),
        child: Icon(
          icon,
          size: iconSize ?? AppDimens.postCreateActionButtonIconSize,
          color: iconColor,
        ),
      ),
    );
  }

  // ---- 发布按钮 ----

  Widget _submitButton(bool canSubmit) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return SizedBox(
      height: AppDimens.postCreateSubmitHeight,
      child: ElevatedButton(
        onPressed: canSubmit ? _submit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.postCreate.submitBg,
          foregroundColor: colors.postCreate.submitText,
          elevation: 0,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.symmetric(
            horizontal: AppDimens.postCreateSubmitHPadding,
            vertical: 0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppDimens.postCreateSubmitRadius,
            ),
          ),
          textStyle: TextStyle(fontSize: AppDimens.postCreateSubmitFontSize),
        ),
        child: _submitting || _uploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('发布'),
      ),
    );
  }
}

class _PreviewThumb extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _PreviewThumb({
    super.key,
    required this.path,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          SizedBox(
            width: AppDimens.postCreatePreviewThumbSize,
            height: AppDimens.postCreatePreviewThumbSize,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(File(path), fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: colors.common.surface.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  size: 12,
                  color: colors.common.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
