import 'package:flutter/material.dart';
import '../models/post.dart';
import '../theme/app_dimens.dart';
import '../theme/app_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/storage.dart';
import '../services/api.dart';
import 'dart:typed_data';

class PostCard extends StatefulWidget {
  final Post post;
  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _expanded = false;
  bool _hasBeenExpanded = false;

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

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isLong = post.content.length > AppDimens.contentMaxLength;
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
                color: colors.borderColor,
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
                        color: colors.borderColor,
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
          _dateRow(colors, isLong),
          SizedBox(height: AppDimens.dateRowBottomSpacing),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text(post.title,
                style: TextStyle(
                    fontSize: AppDimens.fontSizeTitle,
                    fontWeight: FontWeight.w400,
                    color: primary)),
          ),
          if (post.author.isNotEmpty) ...[
            SizedBox(width: AppDimens.paddingLg),
            Text('@',
                style: TextStyle(
                    fontSize: AppDimens.fontSizeAt,
                    color: colors.green,
                    fontStyle: FontStyle.italic)),
            SizedBox(width: AppDimens.authorAtGap),
            Text(post.author,
                style: TextStyle(
                    fontSize: AppDimens.fontSizeAuthor,
                    color: colors.authorColor)),
          ],
        ],
      ),
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

  Widget _buildSingleImage(post) {
    return Padding(
      padding: EdgeInsets.only(top: AppDimens.cardImageTop),
      child: SizedBox(
        width: AppDimens.singleImageWidth,
        height: AppDimens.singleImageHeight,
        child: ThumbnailImage(
            key: ValueKey(post.images[0].fileName),
            fileName: post.images[0].fileName),
      ),
    );
  }

  Widget _buildGrid(post) {
    return Padding(
      padding: EdgeInsets.only(top: AppDimens.cardImageTop),
      child: Wrap(
        spacing: AppDimens.thumbnailGap,
        runSpacing: AppDimens.thumbnailGap,
        children: post.images.take(12).map<Widget>((img) {
          return SizedBox(
            width: AppDimens.gridImageSize,
            height: AppDimens.gridImageSize,
            child: ThumbnailImage(
                key: ValueKey(img.fileName), fileName: img.fileName),
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

  Widget _dateRow(AppColors colors, bool isLong) {
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

class ThumbnailImage extends StatefulWidget {
  final String fileName;
  const ThumbnailImage({super.key, required this.fileName});

  @override
  State<ThumbnailImage> createState() => _ThumbnailImageState();
}

class _ThumbnailImageState extends State<ThumbnailImage> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = PostStorage.getThumbnail(widget.fileName);
    if (cached != null) {
      setState(() { _bytes = cached; _loading = false; });
      return;
    }
    final downloaded = await ApiService.downloadThumbnail(widget.fileName);
    if (!mounted) return;
    if (downloaded != null) {
      await PostStorage.saveThumbnail(widget.fileName, downloaded);
      setState(() { _bytes = downloaded; });
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: Image(image: AssetImage('assets/loading.gif'), width: AppDimens.loadingGifThumbSize, height: AppDimens.loadingGifThumbSize));
    }
    if (_bytes != null) {
      return Image.memory(_bytes!, fit: BoxFit.cover);
    }
    return Image.asset('assets/404.png', fit: BoxFit.cover);
  }
}
