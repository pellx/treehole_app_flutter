import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../theme/app_dimens.dart';
import '../theme/app_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/storage.dart';
import '../services/api.dart';
import '../pages/account/account_page.dart';
import 'dart:typed_data';
import 'image_overlay.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final List<Comment> comments; // 帖子回复列表
  final VoidCallback? onNeedCommentRefresh;
  final void Function(Comment comment)? onCommentCreated; // 评论成功后直接插入
  final ValueChanged<bool>? onCommentOverlayChanged; // 评论浮层显隐通知
  const PostCard({super.key, required this.post, this.comments = const [], this.onNeedCommentRefresh, this.onCommentCreated, this.onCommentOverlayChanged});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _expanded = false;           // 正文是否展开
  bool _hasBeenExpanded = false;    // 是否被展开过（控制图标颜色）
  int _commentsShowCount = AppDimens.commentMaxShown; // 当前展开的回复数
  int? _expandedAuthorId;           // 当前展开的回复署名 ID
  final GlobalKey _dotsKey = GlobalKey(); // 两点按钮定位
  OverlayEntry? _actionOverlay;     // 操作浮层
  OverlayEntry? _commentOverlay;   // 评论输入浮层
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  bool _commentHasAuthor = false;
  bool _commentMultiLine = false;  // 多行时去掉垂直 padding
  bool _commentHadText = false;    // 跟踪是否有文字（发送按钮状态）
  String? _commentAuthorHint;      // 署名提示文字
  Timer? _commentAuthorTimer;
  final _commentTextFieldKey = GlobalKey(); // 保持 TextField 状态跨重建
  final _cardKey = GlobalKey();              // 卡片定位
  final _dateRowKey = GlobalKey();            // 日期行定位
  final _commentSectionKey = GlobalKey();      // 回复区域底部定位
  bool _commentKeyboardVisible = false;     // 跟踪键盘状态
  double _commentLastBottomInset = 0;        // 上次键盘高度

  @override
  void initState() {
    super.initState();
    widget.onNeedCommentRefresh?.call();
    _commentController.addListener(_onCommentTextChanged);
  }

  void _onCommentFocusChanged() {
    if (!_commentFocusNode.hasFocus) {
      _dismissCommentOverlay();
    }
  }

  void _onCommentTextChanged() {
    final text = _commentController.text.trim();
    final hasText = text.isNotEmpty;
    final needsRebuild = hasText != _commentHadText;

    // 文本空/非空状态变化 → 重建（更新发送按钮）
    if (hasText != _commentHadText) {
      _commentHadText = hasText;
    }

    // 保存草稿
    PostStorage.saveCommentDraft(widget.post.id, _commentController.text);

    if (text.isEmpty) {
      if (_commentMultiLine || needsRebuild) {
        _commentMultiLine = false;
        _commentOverlay?.markNeedsBuild();
      }
      return;
    }

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 14, height: 1.4),
      ),
      textDirection: TextDirection.ltr,
    );
    final screenW = MediaQuery.of(context).size.width;
    final availW = screenW - AppDimens.commentInputSectionMarginBottom * 2
        - AppDimens.commentInputAuthorBtnSize * 2
        - AppDimens.commentInputBtnGap * 2
        - AppDimens.commentInputPaddingH * 2;
    painter.layout(maxWidth: availW);
    final isMulti = painter.height > 19.6 * 1.2;

    if (isMulti != _commentMultiLine || needsRebuild) {
      _commentMultiLine = isMulti;
      _commentOverlay?.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _commentController.removeListener(_onCommentTextChanged);
    _commentOverlay?.remove();
    _commentAuthorTimer?.cancel();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  String _dateTransform(String dateStr) {
    if (dateStr.isEmpty) return '';
    final date = DateTime.parse(dateStr);
    final y = date.year.toString().substring(2);
    final m = date.month;
    final d = date.day;
    final h = date.hour.toString().padLeft(2, '0');
    final mi = date.minute.toString().padLeft(2, '0');
    return '$y.$m.$d-$h:$mi';
  }

  String _timeTransform(String dateStr) {
    if (dateStr.isEmpty) return '';
    final date = DateTime.parse(dateStr);
    final h = date.hour.toString().padLeft(2, '0');
    final mi = date.minute.toString().padLeft(2, '0');
    return '$h:$mi';
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isLong = post.content.length > AppDimens.contentMaxLength;
    final remaining = isLong ? post.content.length - AppDimens.contentMaxLength : 0;
    final displayContent = (_expanded || !isLong)
        ? post.content
        : post.content.substring(0, AppDimens.contentMaxLength);
    final hasBody = post.content.isNotEmpty ||
        post.images.isNotEmpty ||
        post.attachments.isNotEmpty;

    final colors = Theme.of(context).extension<AppColors>()!;
    final primary = Theme.of(context).colorScheme.onSurface;
    final pc = colors.postCard;

    return Padding(
      key: _cardKey,
      padding: EdgeInsets.only(
        bottom: AppDimens.cardMarginBottom,
        left: AppDimens.cardLeftMargin,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: pc.cardBorder,
                width: AppDimens.cardBorderWidth,
              ),
              borderRadius:
                  BorderRadius.circular(AppDimens.cardBorderRadius),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _titleRow(post, primary, colors),
                    if (hasBody)
                      Container(
                        height: AppDimens.cardBorderWidth,
                color: pc.cardBorder,
                      ),
                    if (hasBody)
                      Padding(
                        padding: EdgeInsets.only(
                          left: AppDimens.cardHPadding,
                          right: AppDimens.cardHPadding,
                          top: AppDimens.cardBodySpacing,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (post.content.isNotEmpty)
                              _content(displayContent, pc),
                            if (post.images.isNotEmpty) _images(post),
                            if (post.attachments.isNotEmpty)
                              _attachments(post, colors),
                          ],
                        ),
                      ),
                  ],
                ),
                _idWidget(post, pc),
              ],
            ),
          ),
          SizedBox(height: AppDimens.dateRowTopSpacing),
          Container(key: _dateRowKey, child: _dateRow(colors, isLong, remaining)),
          SizedBox(height: AppDimens.dateRowBottomSpacing),
          if (widget.comments.isNotEmpty) _commentSection(colors, primary),
        ],
      ),
    );
  }

  Widget _titleRow(post, Color primary, AppColors colors) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppDimens.cardHPadding,
        right: AppDimens.cardHPadding,
        top: AppDimens.titleVPadding,
        bottom: AppDimens.titleVPadding,
      ),
      child: _TitleAuthorRow(post: post, primary: primary, colors: colors),
    );
  }

  Widget _idWidget(post, PostCardColors pc) {
    final len = post.id.toString().length;

    final child = ColorFiltered(
        colorFilter: ColorFilter.mode(
            pc.idTint,
            BlendMode.srcIn,
          ),
          child: SizedBox(
            width: AppDimens.idImageOverlap * (len - 1) +
                AppDimens.idDigitWidth,
            height: AppDimens.idImageHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: List.generate(len, (i) {
                final digit = post.id.toString()[i];
                return Positioned(
                  left: i * AppDimens.idImageOverlap * 1.0,
                  child: Image.asset(
                    'assets/numbers/$digit.png',
                    width: AppDimens.idDigitWidth,
                    height: AppDimens.idImageHeight,
                    fit: BoxFit.fill,
                    errorBuilder: (context, error, stackTrace) =>
                        Text(digit,
                            style: TextStyle(
                                fontSize: AppDimens.fontSizeId,
                                color: pc.idErrorFallback)),
                  ),
                );
              }),
            ),
          ),
        );

    Widget content = child;
    if (AppDimens.idVertical) {
      content = RotatedBox(quarterTurns: 3, child: content);
    }

    return Positioned(
      left: AppDimens.idRight,
      top: AppDimens.idTop,
      child: content,
    );
  }
  Widget _content(String displayContent, PostCardColors pc) {
    return Text(displayContent,
        style: TextStyle(
            fontSize: AppDimens.fontSizeContent,
            color: pc.content,
            height: AppDimens.contentLineHeight));
  }

  Widget _images(post) {
    if (post.images.isEmpty) return const SizedBox.shrink();
    final count = post.images.length;

    if (count == 1) {
      return _buildSingleImage(post);
    } else {
      return _buildGrid(post);
    }
  }

  List<GlobalKey> _gridKeys = [];
  List<GlobalKey> _singleKey = [];

  void _openOverlay(List<PostImage> images, int index, List<GlobalKey> keys) {
    if (ImageOverlay.currentEntry != null) return;
    final rects = <Rect?>[];
    for (final key in keys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) {
        rects.add(null);
        continue;
      }
      final offset = box.localToGlobal(Offset.zero);
      final size = box.size;
      rects.add(Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height));
    }
    // 确保至少有 index 对应的 rect
    while (rects.length <= index) rects.add(null);

    final thumbs = <Uint8List?>[];
    for (final img in images) {
      thumbs.add(PostStorage.getThumbnail(img.fileName)?.bytes);
    }

    final overlay = Overlay.of(context);
    ImageOverlay.currentEntry = OverlayEntry(builder: (_) {
      return ImageOverlay(
        images: images,
        initialIndex: index,
        thumbRects: rects,
        thumbnails: thumbs,
      );
    });
    overlay.insert(ImageOverlay.currentEntry!);
  }

  Widget _buildSingleImage(post) {
    if (_singleKey.isEmpty) _singleKey = [GlobalKey()];
    return GestureDetector(
      onTap: () => _openOverlay(post.images, 0, _singleKey),
      child: Padding(
        padding: EdgeInsets.only(top: AppDimens.cardImageTop, bottom: AppDimens.cardImageBottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: AppDimens.singleImageMaxRatio * AppDimens.titleAuthorMaxWidth,
          ),
          child: SizedBox(
            key: _singleKey[0],
            child: ThumbnailImage(
                key: ValueKey(post.images[0].fileName),
                fileName: post.images[0].fileName,
                fit: BoxFit.contain,
                constrainSingle: true),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(post) {
    if (_gridKeys.length != post.images.length) {
      _gridKeys = List.generate(post.images.length, (_) => GlobalKey());
    }

    return Padding(
      padding: EdgeInsets.only(top: AppDimens.cardImageTop, bottom: AppDimens.cardImageBottom),
      child: Wrap(
        spacing: AppDimens.thumbnailGap,
        runSpacing: AppDimens.thumbnailGap,
        children: post.images.asMap().entries.take(12).map<Widget>((entry) {
          final i = entry.key;
          final img = entry.value;
          return GestureDetector(
            onTap: () => _openOverlay(post.images, i, _gridKeys),
            child: SizedBox(
              key: _gridKeys[i],
              width: AppDimens.gridImageSize,
              height: AppDimens.gridImageSize,
              child: ThumbnailImage(
                  key: ValueKey(img.fileName), fileName: img.fileName),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _attachments(post, AppColors colors) {
    final pc = colors.postCard;
    return Padding(
      padding: EdgeInsets.only(top: AppDimens.paddingSm),
      child: Column(
        children: post.attachments.map<Widget>((att) {
          return Text('📎 ${att.sourceName}',
              style: TextStyle(
                  fontSize: AppDimens.fontSizeSmall,
                  color: pc.attachmentText));
        }).toList(),
      ),
    );
  }

  // 回复区域：无边框，默认折叠显示前 commentMaxShown 条，末尾右侧有展开/收起按钮
  Widget _commentSection(AppColors colors, Color primary) {
    final pc = colors.postCard;
    final all = widget.comments;
    final showMore = all.length > _commentsShowCount;
    final hasMinus = _commentsShowCount > AppDimens.commentMaxShown;
    final visible = all.take(_commentsShowCount).toList();
    final postDay = widget.post.createdAt.length >= 10
        ? widget.post.createdAt.substring(0, 10)
        : '';

    String? lastDay;
    final rows = <Widget>[];
    for (int i = 0; i < visible.length; i++) {
      final cmtDay = visible[i].createdAt.length >= 10
          ? visible[i].createdAt.substring(0, 10)
          : '';
      if (cmtDay != postDay && cmtDay != lastDay) {
        rows.add(Padding(
          key: ValueKey('sep_$cmtDay'),
          padding: EdgeInsets.only(bottom: AppDimens.commentVPadding),
          child: _commentDateSeparator(visible[i].createdAt, colors),
        ));
      }
      rows.add(Padding(
        key: ValueKey('cmt_${visible[i].id}'),
        padding: EdgeInsets.only(bottom: AppDimens.commentVPadding),
        child: _commentRow(visible[i], colors, primary, _expandedAuthorId == visible[i].id),
      ));
      lastDay = cmtDay;
    }
    if (showMore || hasMinus) {
      final remain = all.length - _commentsShowCount;
      rows.add(Align(
        key: const ValueKey('comment_btns'),
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showMore) ...[
              Padding(
                padding: EdgeInsets.only(top: AppDimens.commentRemainTopOffset),
                child: Text(
                  '+$remain',
                  style: TextStyle(
                    fontSize: AppDimens.commentRemainFontSize,
                    color: pc.commentRemain,
                  ),
                ),
              ),
              SizedBox(width: AppDimens.commentRemainBtnGap),
            ],
            if (hasMinus)
              GestureDetector(
                onTap: () => setState(() => _commentsShowCount = AppDimens.commentMaxShown),
                child: SvgPicture.asset(
                  'assets/minus.svg',
                  width: AppDimens.commentBtnSize,
                  height: AppDimens.commentBtnSize,
                  colorFilter: ColorFilter.mode(pc.commentIcon, BlendMode.srcIn),
                ),
              ),
            if (showMore && hasMinus) SizedBox(width: AppDimens.commentBtnGap),
            if (showMore)
              GestureDetector(
                onTap: () => setState(() => _commentsShowCount += AppDimens.commentStep),
                child: SvgPicture.asset(
                  'assets/plus.svg',
                  width: AppDimens.commentBtnSize,
                  height: AppDimens.commentBtnSize,
                  colorFilter: ColorFilter.mode(pc.commentIcon, BlendMode.srcIn),
                ),
              ),
          ],
        ),
      ));
    }

    return Container(
      key: _commentSectionKey,
      margin: EdgeInsets.only(top: AppDimens.commentSectionMarginTop),
      decoration: BoxDecoration(
        color: pc.commentBg,
        borderRadius: BorderRadius.circular(AppDimens.commentBgRadius),
      ),
      padding: EdgeInsets.only(
        left: AppDimens.paddingSm,
        right: AppDimens.paddingSm,
        top: AppDimens.commentSectionTopPadding,
        bottom: AppDimens.cardBodySpacing,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }

  Widget _commentDateSeparator(String dateStr, AppColors colors) {
    final pc = colors.postCard;
    return Padding(
      padding: EdgeInsets.only(bottom: AppDimens.commentVPadding),
      child: Row(
        children: [
          Text(
            _dateOnlyTransform(dateStr),
            style: TextStyle(
              fontSize: AppDimens.commentDateFontSize,
              color: pc.commentDate,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: AppDimens.commentDateLineTopOffset),
              child: Container(
                height: 1,
                color: pc.commentDateSeparatorLine,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 评论输入覆盖层（全屏宽 + 键盘同步）----

  Widget _buildCommentOverlay() {
    return Builder(
      builder: (ctx) {
        final colors = Theme.of(ctx).extension<AppColors>()!;
        final pc = colors.postCard;
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        final safeBottom = MediaQuery.of(ctx).padding.bottom;
        final keyboardUp = bottomInset > 0;

        // 键盘高度下降 → 立即关闭输入栏
        if (_commentKeyboardVisible && bottomInset < _commentLastBottomInset) {
          _commentKeyboardVisible = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _dismissCommentOverlay();
          });
        } else {
          _commentKeyboardVisible = keyboardUp;
        }
        _commentLastBottomInset = bottomInset;

        return Material(
          color: Colors.transparent,
          child: Stack(
          children: [
            // 署名提示（输入栏上方）
            if (_commentAuthorHint != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: (bottomInset > 0 ? bottomInset : safeBottom + AppDimens.commentInputSectionMarginBottom)
                    + AppDimens.commentInputHeight + AppDimens.commentInputAuthorHintOffset,
                child: Center(
                  child: Text(
                    _commentAuthorHint!,
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.postCreate.bottomHintText,
                    ),
                  ),
                ),
              ),
            // 输入栏贴在键盘上方
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset > 0 ? bottomInset : safeBottom + AppDimens.commentInputSectionMarginBottom,
              child: Container(
                color: pc.commentInputBarBg,
                padding: EdgeInsets.only(
                  left: AppDimens.commentInputSectionMarginBottom,
                  right: AppDimens.commentInputSectionMarginBottom,
                  top: AppDimens.commentInputSectionMarginTop,
                  bottom: bottomInset > 0 ? AppDimens.commentInputSectionMarginBottom : 0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: AppDimens.commentInputHeight,
                          maxHeight: AppDimens.commentInputMaxHeight,
                        ),
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: pc.commentInputFieldBg,
                                borderRadius: BorderRadius.circular(AppDimens.commentInputRadius),
                              ),
                              child: TextField(
                                  key: _commentTextFieldKey,
                                  controller: _commentController,
                                focusNode: _commentFocusNode,
                                autofocus: true,
                                minLines: 1,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                textAlignVertical: _commentMultiLine
                                    ? TextAlignVertical.top
                                    : TextAlignVertical.center,
                                style: TextStyle(
                                  fontSize: AppDimens.commentInputFontSize,
                                  color: pc.commentContent,
                                  height: 1.4,
                                ),
                                decoration: InputDecoration(
                                  hintText: '输入评论...',
                                  hintStyle: TextStyle(
                                    fontSize: AppDimens.commentInputFontSize,
                                    color: pc.commentDate,
                                    height: 1.4,
                                  ),
                                  contentPadding: _commentMultiLine
                                      ? EdgeInsets.symmetric(horizontal: AppDimens.commentInputPaddingH)
                                      : EdgeInsets.fromLTRB(
                                          AppDimens.commentInputPaddingH,
                                          10,
                                          AppDimens.commentInputPaddingH,
                                          10,
                                        ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _submitComment(),
                              ),
                            ),
                            if (!PostStorage.isRegistered())
                              Positioned.fill(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountPage()));
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: pc.commentInputFieldBg,
                                      borderRadius: BorderRadius.circular(AppDimens.commentInputRadius),
                                    ),
                                    alignment: Alignment.centerLeft,
                                    padding: _commentMultiLine
                                        ? EdgeInsets.symmetric(horizontal: AppDimens.commentInputPaddingH)
                                        : EdgeInsets.fromLTRB(
                                            AppDimens.commentInputPaddingH,
                                            10,
                                            AppDimens.commentInputPaddingH,
                                            10,
                                          ),
                                    child: Text(
                                      '目前未绑定账号，请注册',
                                      style: TextStyle(
                                        fontSize: AppDimens.commentInputFontSize,
                                        color: pc.commentDate,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: AppDimens.commentInputBtnGap),
                    _commentAuthorBtn(colors),
                    SizedBox(width: AppDimens.commentInputBtnGap),
                    _commentSendBtn(colors),
                  ],
                ),
              ),
            ),
          ],
          ),
        );
      },
    );
  }

  Widget _commentAuthorBtn(AppColors colors) {
    return GestureDetector(
      onTap: () {
        _commentHasAuthor = !_commentHasAuthor;
        _commentAuthorTimer?.cancel();
        _commentAuthorHint = _commentHasAuthor ? '开启署名' : '关闭署名';
        _commentOverlay?.markNeedsBuild();
        _commentAuthorTimer = Timer(const Duration(milliseconds: AppDimens.commentInputAuthorHintMs), () {
          _commentAuthorHint = null;
          _commentOverlay?.markNeedsBuild();
        });
      },
      child: Container(
        width: AppDimens.commentInputAuthorBtnSize,
        height: AppDimens.commentInputAuthorBtnSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimens.commentInputAuthorBtnRadius),
          color: _commentHasAuthor
              ? colors.postCreate.authorActiveFill
              : colors.postCreate.fieldBg,
          border: Border.all(
            color: _commentHasAuthor
                ? colors.postCreate.authorActiveFill
                : colors.postCreate.authorBorder,
            width: AppDimens.commentInputAuthorBtnBorderWidth,
          ),
        ),
        child: Icon(
          _commentHasAuthor ? Icons.person : Icons.person_outline,
          size: AppDimens.commentInputAuthorBtnIconSize,
          color: _commentHasAuthor
              ? colors.postCreate.authorActiveIcon
              : colors.postCreate.authorIcon,
        ),
      ),
    );
  }

  Widget _commentSendBtn(AppColors colors) {
    final hasText = _commentController.text.trim().isNotEmpty;
    final pc = colors.postCard;
    return GestureDetector(
      onTap: hasText ? _submitComment : null,
      child: Container(
        width: AppDimens.commentInputAuthorBtnSize,
        height: AppDimens.commentInputAuthorBtnSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimens.commentInputAuthorBtnRadius),
          color: hasText ? pc.commentSendActiveBg : pc.commentSendInactiveBg,
          border: Border.all(
            color: hasText ? pc.commentSendActiveBg : pc.commentSendInactiveBorder,
            width: AppDimens.commentInputAuthorBtnBorderWidth,
          ),
        ),
        child: Icon(
          Icons.send,
          size: AppDimens.commentInputAuthorBtnIconSize,
          color: hasText ? pc.commentSendActiveIcon : pc.commentSendInactiveIcon,
        ),
      ),
    );
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    final author = _commentHasAuthor ? PostStorage.getUserName() : '';
    final result = await ApiService.createComment(
      postId: widget.post.id,
      content: content,
      author: author,
    );
    if (!mounted) return;
    if (result != null) {
      _commentController.clear();
      PostStorage.clearCommentDraft(widget.post.id);
      PostStorage.saveComment(result);
      widget.onCommentCreated?.call(result);
      _dismissCommentOverlay();
      widget.onNeedCommentRefresh?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiService.lastError ?? '评论发送失败'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _dateOnlyTransform(String dateStr) {
    if (dateStr.isEmpty) return '';
    final date = DateTime.parse(dateStr);
    final y = date.year.toString().substring(2);
    final m = date.month;
    final d = date.day;
    return '$y.$m.$d';
  }

  // 单条回复行：[时间] 内容(单行截断) [署名]
  Widget _commentRow(Comment comment, AppColors colors, Color primary, bool isExpanded) {
    final pc = colors.postCard;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AppDimens.commentDateWidth,
          child: Text(
            _timeTransform(comment.createdAt),
            style: TextStyle(
              fontSize: AppDimens.commentDateFontSize,
              color: pc.commentDate,
            ),
          ),
        ),
        SizedBox(width: AppDimens.commentDateRightMargin),
        Expanded(
          child: Text(
            comment.content,
            maxLines: AppDimens.commentMaxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppDimens.commentFontSize,
              color: pc.commentContent,
              height: AppDimens.commentLineHeight,
            ),
          ),
        ),
        SizedBox(width: AppDimens.commentDateRightMargin),
        GestureDetector(
          onTap: () {
            setState(() {
              _expandedAuthorId = isExpanded ? null : comment.id;
            });
          },
          child: SizedBox(
            width: isExpanded ? null : AppDimens.commentAuthorWidth,
            child: Text(
              comment.author,
              maxLines: isExpanded ? 1000 : 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: AppDimens.commentAuthorFontSize,
                color: pc.commentAuthor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateRow(AppColors colors, bool isLong, int remaining) {
    final pc = colors.postCard;
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Padding(
          padding: EdgeInsets.only(left: AppDimens.paddingSm),
          child: Text(_dateTransform(widget.post.createdAt),
              style: TextStyle(
                  fontSize: AppDimens.fontSizeSmall,
                  color: pc.dateText)),
        ),
          if (isLong && !_hasBeenExpanded)
            Positioned(
              top: AppDimens.expandIconTop,
              right: AppDimens.dotsPositionedRight +
                  AppDimens.dotsBtnWidth +
                  AppDimens.expandBtnDotsGap +
                  AppDimens.expandIconSize +
                  AppDimens.expandRemainGap,
              child: Text(
                '+$remaining',
                style: TextStyle(
                  fontSize: AppDimens.fontSizeSmall,
              color: pc.commentDate,
                ),
              ),
            ),
          if (isLong)
            Positioned(
              top: AppDimens.expandIconTop,
              right: AppDimens.dotsPositionedRight +
                  AppDimens.dotsBtnWidth +
                  AppDimens.expandBtnDotsGap,
              child: GestureDetector(
                onTap: () => setState(() {
                  _expanded = !_expanded;
                  _hasBeenExpanded = true;
                }),
                child: AnimatedRotation(
                  turns: _expanded ? 0.0 : 0.5,
                  duration: Duration(milliseconds: AppDimens.expandIconAnimMs),
                  child: SvgPicture.asset(
                    'assets/expand_icon.svg',
                    width: AppDimens.expandIconSize,
                    height: AppDimens.expandIconSize,
                    colorFilter: ColorFilter.mode(
                      _hasBeenExpanded
                          ? pc.expandIconGray
                          : pc.expandIconBlue,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
        // 两点按钮
        Positioned(
          right: AppDimens.dotsPositionedRight,
          top: AppDimens.dotsPositionedTop,
          child: _dotsOnly(pc),
        ),
      ],
    );
  }

  // ---- 两点按钮（点击弹出浮层）----

  Widget _dotsOnly(PostCardColors pc) {
    return GestureDetector(
      key: _dotsKey,
      onTap: () => _toggleOverlay(pc),
      child: Container(
        width: AppDimens.dotsBtnWidth,
        height: AppDimens.dotsBtnHeight,
        decoration: BoxDecoration(
          color: pc.dotsButtonBg,
          borderRadius: BorderRadius.circular(AppDimens.dotsBtnRadius),
        ),
        child: Stack(
          children: [
            Positioned(
              top: AppDimens.dotsTopPadding,
              left: AppDimens.dotsLeftPadding,
              child: Text('·',
                  style: const TextStyle(
                      fontSize: AppDimens.dotsFontSize,
                      fontWeight: FontWeight.bold)),
            ),
            Positioned(
              top: AppDimens.dotsTopPadding,
              right: AppDimens.dotsRightPadding,
              child: Text('·',
                  style: const TextStyle(
                      fontSize: AppDimens.dotsFontSize,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleOverlay(PostCardColors pc) {
    if (_actionOverlay != null) {
      _actionOverlay!.remove();
      _actionOverlay = null;
      return;
    }

    final renderBox =
        _dotsKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final buttonPos = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;

    _actionOverlay = OverlayEntry(
      builder: (_) => _buildOverlayContent(pc, buttonPos, buttonSize),
    );
    Overlay.of(context).insert(_actionOverlay!);
  }

  Widget _buildOverlayContent(
      PostCardColors pc, Offset buttonPos, Size buttonSize) {
    final boxWidth = 3 * AppDimens.actionMenuBtnWidth +
        2 * 1 + // 两条竖线
        AppDimens.paddingSm * 2;
    final boxHeight = AppDimens.actionMenuBoxHeight;

    // 方框在按钮左侧，顶对齐
    final boxRight = buttonPos.dx +
        buttonSize.width +
        AppDimens.actionMenuBoxRightOffset;
    final boxLeft = boxRight - boxWidth;
    final boxTop = buttonPos.dy + AppDimens.actionMenuBoxTopOffset;

    return Stack(
      children: [
        // 全屏透明遮罩（点击收起）
        GestureDetector(
          onTap: _dismissOverlay,
          behavior: HitTestBehavior.translucent,
          child: Container(color: Colors.transparent),
        ),
        // 浮动方框
        Positioned(
          left: boxLeft,
          top: boxTop,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: boxWidth,
              height: boxHeight,
              decoration: BoxDecoration(
                color: pc.actionMenuBg,
                borderRadius:
                    BorderRadius.circular(AppDimens.dotsBtnRadius),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: AppDimens.paddingSm),
                  _actionIcon('assets/icons/game-pack/report.svg', '举报', pc,
                      AppDimens.actionMenuIconSizeReport, _onReport),
                  _actionDivider(pc),
                  _actionIcon('assets/icons/game-pack/five-pointed-star.svg', '收藏', pc,
                      AppDimens.actionMenuIconSizeFavorite, _onFavorite),
                  _actionDivider(pc),
                  _actionIcon('assets/icons/game-pack/message.svg', '回复', pc,
                      AppDimens.actionMenuIconSizeComment, _onComment),
                  SizedBox(width: AppDimens.paddingSm),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _dismissOverlay() {
    _actionOverlay?.remove();
    _actionOverlay = null;
  }

  // ---- 操作图标 ----

  Widget _actionIcon(String assetPath, String tooltip, PostCardColors pc,
      double iconSize, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: AppDimens.actionMenuBtnWidth,
          height: AppDimens.actionMenuBtnHeight,
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(AppDimens.actionMenuBtnRadius),
          ),
          child: Center(
            child: SvgPicture.asset(
              assetPath,
              width: iconSize,
              height: iconSize,
              colorFilter: ColorFilter.mode(pc.actionBtnText, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionDivider(PostCardColors pc) {
    return Container(
      width: 1,
      height: 12,
      decoration: BoxDecoration(
        color: pc.actionBtnText.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(0.5),
      ),
    );
  }

  // ---- 菜单操作处理 ----

  void _onFavorite() {
    _dismissOverlay();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('收藏功能即将上线'),
          duration: Duration(seconds: 1)),
    );
  }

  void _onComment() {
    _dismissOverlay();
    if (_commentOverlay != null) {
      _dismissCommentOverlay();
      return;
    }
    final overlay = Overlay.of(context);
    _commentOverlay = OverlayEntry(
      builder: (_) => _buildCommentOverlay(),
    );
    overlay.insert(_commentOverlay!);
    // 恢复草稿
    final draft = PostStorage.getCommentDraft(widget.post.id);
    if (draft != null && draft.isNotEmpty) {
      _commentController.text = draft;
    }
    _commentKeyboardVisible = false;
    widget.onCommentOverlayChanged?.call(true);
    // 先聚焦唤出键盘，再滚动对齐
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _commentOverlay == null) return;
      _commentFocusNode.requestFocus();
      // 等键盘出现后再滚动
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted || _commentOverlay == null) return;
        final hasComments = widget.comments.isNotEmpty;
        final ctx = hasComments
            ? _commentSectionKey.currentContext
            : _dateRowKey.currentContext;
        if (ctx != null) {
          final box = ctx.findRenderObject() as RenderBox;
          final scrollable = Scrollable.of(ctx);
          // 目标区域底部在视口中的位置
          final targetBottom = box.localToGlobal(Offset.zero).dy + box.size.height;
          final scrollTop = scrollable.context.findRenderObject() as RenderBox;
          final viewportTop = scrollTop.localToGlobal(Offset.zero).dy;
          final targetBottomInViewport = targetBottom - viewportTop;
          // 有评论定位评论区底部，无评论定位日期行底部
          final offset = hasComments
              ? AppDimens.commentScrollBottomOffset
              : AppDimens.dateRowScrollBottomOffset;
          final desiredBottom = scrollable.position.viewportDimension - offset;
          final delta = targetBottomInViewport - desiredBottom;
          if (delta.abs() > 2) {
            scrollable.position.animateTo(
              (scrollable.position.pixels + delta).clamp(
                scrollable.position.minScrollExtent,
                scrollable.position.maxScrollExtent,
              ),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        }
      });
    });
  }

  void _dismissCommentOverlay() {
    final hadOverlay = _commentOverlay != null;
    _commentOverlay?.remove();
    _commentOverlay = null;
    _commentFocusNode.unfocus();
    _commentHadText = false;
    if (hadOverlay) {
      widget.onCommentOverlayChanged?.call(false);
    }
  }

  void _onReport() {
    _dismissOverlay();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('举报功能即将上线'),
          duration: Duration(seconds: 1)),
    );
  }
}

class _TitleAuthorRow extends StatelessWidget {
  final dynamic post;
  final Color primary;
  final AppColors colors;

  const _TitleAuthorRow({
    required this.post,
    required this.primary,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final pc = colors.postCard;
    final titleStyle = TextStyle(
        fontSize: AppDimens.fontSizeTitle,
        fontWeight: FontWeight.w400,
        color: pc.title);
    final authorStyle = TextStyle(
        fontSize: AppDimens.fontSizeAuthor,
        color: pc.authorName);
    final atStyle = TextStyle(
        fontSize: AppDimens.fontSizeAt,
        color: pc.atSymbol,
        fontStyle: FontStyle.italic);

    // 测量标题和作者宽度（标题最多2行）
    final tp = TextPainter(
        text: TextSpan(text: post.title, style: titleStyle),
        maxLines: 2,
        textDirection: TextDirection.ltr)..layout();
    final ap = TextPainter(
        text: TextSpan(text: '@${post.author}', style: authorStyle),
        maxLines: 1,
        textDirection: TextDirection.ltr);
    if (post.author.isNotEmpty) ap.layout();

    final titleW = tp.width;
    final authorW = post.author.isEmpty ? 0 : ap.width + AppDimens.paddingLg;

    return ConstrainedBox(
      constraints:
          BoxConstraints(maxWidth: AppDimens.titleAuthorMaxWidth),
      child: post.author.isEmpty
          ? Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle)
          : titleW + authorW <= AppDimens.titleAuthorMaxWidth
              // 不超宽：都 inline，不换行
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle),
                    SizedBox(width: AppDimens.paddingLg),
                    Text('@', style: atStyle),
                    SizedBox(width: AppDimens.authorAtGap),
                    Text(post.author, style: authorStyle),
                  ],
                )
              // 超宽
              : () {
                  final halfW = AppDimens.titleAuthorMaxWidth / 2;
                  final gap = AppDimens.paddingLg;
                  final bothLong = titleW > halfW && authorW > halfW;

                  double titleFlex, authorFlex;
                  if (bothLong) {
                    // 按比例分配：titleShare = titleW / totalW * maxWidth
                    final totalW = titleW + authorW;
                    final avail = AppDimens.titleAuthorMaxWidth - gap;
                    titleFlex = (titleW / totalW) * avail / avail;
                    authorFlex = (authorW / totalW);
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          flex: (titleW / totalW * avail).round().clamp(1, 999),
                          child: Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis, softWrap: true, style: titleStyle),
                        ),
                        SizedBox(width: gap),
                        Flexible(
                          flex: (authorW / totalW * avail).round().clamp(1, 999),
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(text: '@', style: atStyle),
                              TextSpan(text: post.author, style: authorStyle),
                            ]),
                            softWrap: true,
                          ),
                        ),
                      ],
                    );
                  } else {
                    // 短的 inline，长的被约束到 maxWidth - 短宽度
                    final titleLong = titleW > halfW;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (titleLong)
                          ConstrainedBox(
                            constraints: BoxConstraints(
                                maxWidth: AppDimens.titleAuthorMaxWidth -
                                    authorW -
                                    gap),
                            child: Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle),
                          )
                        else
                          Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle),
                        SizedBox(width: gap),
                        if (!titleLong)
                          ConstrainedBox(
                            constraints: BoxConstraints(
                                maxWidth: AppDimens.titleAuthorMaxWidth -
                                    titleW -
                                    gap),
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(text: '@', style: atStyle),
                                TextSpan(text: post.author, style: authorStyle),
                              ]),
                            ),
                          )
                        else
                          Text.rich(
                            TextSpan(children: [
                              TextSpan(text: '@', style: atStyle),
                              TextSpan(text: post.author, style: authorStyle),
                            ]),
                          ),
                      ],
                    );
                  }
                }(),
    );
  }
}

class ThumbnailImage extends StatefulWidget {
  final String fileName;
  final BoxFit fit;
  final bool constrainSingle;
  const ThumbnailImage({super.key, required this.fileName, this.fit = BoxFit.cover, this.constrainSingle = false});

  @override
  State<ThumbnailImage> createState() => _ThumbnailImageState();
}

class _ThumbnailImageState extends State<ThumbnailImage> {
  Uint8List? _bytes;
  bool _loading = true;
  double? _displayW;
  double? _displayH;

  @override
  void initState() {
    super.initState();
    _initDims();
    _load();
  }

  void _initDims() {
    if (!widget.constrainSingle) return;
    final data = PostStorage.getThumbnail(widget.fileName);
    if (data != null) _calcDisplaySize(data);
  }

  void _calcDisplaySize(ThumbnailData data) {
    if (data.width > 0 && data.height > 0) {
      final ratio = (data.width / data.height)
          .clamp(AppDimens.singleImageMinRatio, AppDimens.singleImageMaxRatio);
      final h = sqrt(AppDimens.singleImageMaxArea / ratio);
      _displayH = h;
      _displayW = ratio * h;
    }
  }

  Future<void> _load() async {
    final cached = PostStorage.getThumbnail(widget.fileName);
    if (cached != null) {
      _calcDisplaySize(cached);
      setState(() { _bytes = cached.bytes; _loading = false; });
      return;
    }
    final downloaded = await ApiService.downloadThumbnail(widget.fileName);
    if (downloaded != null) {
      await PostStorage.saveThumbnail(widget.fileName, downloaded);
    }
    if (!mounted) return;
    if (downloaded != null) {
      _calcDisplaySize(downloaded);
      setState(() { _bytes = downloaded.bytes; _loading = false; });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultMax = sqrt(AppDimens.singleImageMaxArea);
    if (_loading) {
      final child = const Image(image: AssetImage('assets/loading.gif'), width: AppDimens.loadingGifThumbSize, height: AppDimens.loadingGifThumbSize);
      if (widget.constrainSingle) {
        final w = _displayW ?? defaultMax;
        final h = _displayH ?? defaultMax;
        return SizedBox(
          width: w,
          height: h,
          child: Center(child: child),
        );
      }
      return Center(child: child);
    }
    if (_bytes != null) {
      Widget img = Image.memory(_bytes!, fit: widget.fit);
      if (widget.constrainSingle) {
        final w = _displayW ?? defaultMax;
        final h = _displayH ?? defaultMax;
        img = SizedBox(
          width: w,
          height: h,
          child: img,
        );
      }
      return img;
    }
    if (widget.constrainSingle) {
      return SizedBox(
        width: defaultMax,
        height: defaultMax,
        child: Image.asset('assets/404.png', fit: BoxFit.cover),
      );
    }
    return Image.asset('assets/404.png', fit: BoxFit.cover);
  }
}
