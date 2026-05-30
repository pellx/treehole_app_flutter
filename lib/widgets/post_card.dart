import 'dart:math';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../theme/app_dimens.dart';
import '../theme/app_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/storage.dart';
import '../services/api.dart';
import 'dart:typed_data';
import 'image_overlay.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final List<Comment> comments; // 帖子回复列表
  final VoidCallback? onNeedCommentRefresh;
  const PostCard({super.key, required this.post, this.comments = const [], this.onNeedCommentRefresh});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _expanded = false;           // 正文是否展开
  bool _hasBeenExpanded = false;    // 是否被展开过（控制图标颜色）
  int _commentsShowCount = AppDimens.commentMaxShown; // 当前展开的回复数
  int? _expandedAuthorId;           // 当前展开的回复署名 ID

  @override
  void initState() {
    super.initState();
    widget.onNeedCommentRefresh?.call();
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

    return Padding(
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
                color: colors.borderColor.withValues(alpha: AppDimens.cardBorderOpacity),
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
                color: colors.borderColor.withValues(alpha: AppDimens.cardBorderOpacity),
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
                              _content(displayContent, primary),
                            if (post.images.isNotEmpty) _images(post),
                            if (post.attachments.isNotEmpty)
                              _attachments(post, colors),
                          ],
                        ),
                      ),
                  ],
                ),
                _idWidget(post),
              ],
            ),
          ),
          SizedBox(height: AppDimens.dateRowTopSpacing),
          _dateRow(colors, isLong, remaining),
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

  Widget _idWidget(post) {
    final len = post.id.toString().length;

    final child = Opacity(
        opacity: AppDimens.idOpacity,
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
            Color(AppDimens.idTintColor),
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
                            style: const TextStyle(
                                fontSize: AppDimens.fontSizeId,
                                color: Colors.red)),
                  ),
                );
              }),
            ),
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
  Widget _content(String displayContent, Color primary) {
    return Text(displayContent,
        style: TextStyle(
            fontSize: AppDimens.fontSizeContent,
            color: primary,
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
    return Padding(
      padding: EdgeInsets.only(top: AppDimens.paddingSm),
      child: Column(
        children: post.attachments.map<Widget>((att) {
          return Text('📎 ${att.sourceName}',
              style: TextStyle(
                  fontSize: AppDimens.fontSizeSmall,
                  color: colors.attachment));
        }).toList(),
      ),
    );
  }

  // 回复区域：无边框，默认折叠显示前 commentMaxShown 条，末尾右侧有展开/收起按钮
  Widget _commentSection(AppColors colors, Color primary) {
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
                    color: colors.secondary,
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
                  colorFilter: ColorFilter.mode(colors.secondary, BlendMode.srcIn),
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
                  colorFilter: ColorFilter.mode(colors.secondary, BlendMode.srcIn),
                ),
              ),
          ],
        ),
      ));
    }

    return Container(
      margin: EdgeInsets.only(top: AppDimens.commentSectionMarginTop),
      decoration: BoxDecoration(
        color: colors.secondary.withValues(alpha: AppDimens.commentBgOpacity),
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
    return Padding(
      padding: EdgeInsets.only(bottom: AppDimens.commentVPadding),
      child: Row(
        children: [
          Text(
            _dateOnlyTransform(dateStr),
            style: TextStyle(
              fontSize: AppDimens.commentDateFontSize,
              color: colors.secondary,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: AppDimens.commentDateLineTopOffset),
              child: Container(
                height: 1,
                color: colors.secondary.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AppDimens.commentDateWidth,
          child: Text(
            _timeTransform(comment.createdAt),
            style: TextStyle(
              fontSize: AppDimens.commentDateFontSize,
              color: colors.secondary,
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
              color: primary,
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
                color: colors.authorColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateRow(AppColors colors, bool isLong, int remaining) {
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Padding(
          padding: EdgeInsets.only(left: AppDimens.paddingSm),
          child: Text(_dateTransform(widget.post.createdAt),
              style: TextStyle(
                  fontSize: AppDimens.fontSizeSmall,
                  color: colors.secondary)),
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
                  color: colors.secondary,
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
                          ? colors.secondary.withValues(
                              alpha: AppDimens.expandIconGrayAlpha)
                          : Color(AppDimens.expandIconColorBlue),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
        Positioned(
          right: AppDimens.dotsPositionedRight,
          top: AppDimens.dotsPositionedTop,
          child: Container(
            width: AppDimens.dotsBtnWidth,
            height: AppDimens.dotsBtnHeight,
            decoration: BoxDecoration(
              color: colors.secondary
                  .withValues(alpha: AppDimens.dotsBgOpacity),
              borderRadius:
                  BorderRadius.circular(AppDimens.dotsBtnRadius),
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
        ),
      ],
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
    final titleStyle = TextStyle(
        fontSize: AppDimens.fontSizeTitle,
        fontWeight: FontWeight.w400,
        color: primary);
    final authorStyle = TextStyle(
        fontSize: AppDimens.fontSizeAuthor,
        color: colors.authorColor);
    final atStyle = TextStyle(
        fontSize: AppDimens.fontSizeAt,
        color: colors.green,
        fontStyle: FontStyle.italic);

    // 测量标题和作者宽度
    final tp = TextPainter(
        text: TextSpan(text: post.title, style: titleStyle),
        maxLines: 1,
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
          ? Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle)
          : titleW + authorW <= AppDimens.titleAuthorMaxWidth
              // 不超宽：都 inline，不换行
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(post.title, style: titleStyle),
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
                          child: Text(post.title, softWrap: true, style: titleStyle),
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
                            child: Text(post.title, style: titleStyle),
                          )
                        else
                          Text(post.title, style: titleStyle),
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
