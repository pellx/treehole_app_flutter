import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/post.dart';
import '../services/storage.dart';

class ImageOverlay extends StatefulWidget {
  final List<PostImage> images;
  final int initialIndex;
  final List<Rect?> thumbRects;
  final List<Uint8List?> thumbnails;

  const ImageOverlay({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.thumbRects,
    required this.thumbnails,
  });

  static OverlayEntry? currentEntry;
  static void Function()? _onClose;
  static VoidCallback? onChanged;
  static void closeCurrent() => _onClose?.call();

  static Future<Uint8List?> downloadPng(String fileName) async {
    try {
      final res = await http
          .get(Uri.parse('https://www.leisure.xin:33433/upload/$fileName'))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {}
    return null;
  }

  @override
  State<ImageOverlay> createState() => _ImageOverlayState();
}

class _ImageOverlayState extends State<ImageOverlay>
    with TickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _expandAnim;
  late Animation<Color?> _bgAnim;
  int _currentIndex = 0;
  bool _shown = false;

  final Map<int, Uint8List?> _pngCache = {};
  final Set<int> _loading = {};
  final Map<int, AnimationController> _fadeCtrls = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _expandAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _bgAnim = ColorTween(begin: Colors.transparent, end: Colors.black)
        .animate(_expandAnim);

    _animCtrl.forward().then((_) => setState(() => _shown = true));
    _animCtrl.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        ImageOverlay.currentEntry?.remove();
        ImageOverlay.currentEntry = null;
        ImageOverlay._onClose = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ImageOverlay.onChanged?.call();
        });
      }
    });
    _animCtrl.addListener(() { if (mounted) setState(() {}); });
    ImageOverlay._onClose = _close;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ImageOverlay.onChanged?.call();
    });
  }

  @override
  void dispose() {
    for (final c in _fadeCtrls.values) {
      c.dispose();
    }
    _animCtrl.dispose();
    super.dispose();
  }

  void _loadPng(int index) {
    if (_pngCache.containsKey(index) && _pngCache[index] != null) return;
    if (_loading.contains(index)) return;
    _loading.add(index);

    final fileName = widget.images[index].fileName;

    // 1. 先查文件缓存
    PostStorage.getPng(fileName).then((cached) {
      if (!mounted) return;
      _loading.remove(index);
      if (cached != null) {
        setState(() => _pngCache[index] = cached);
        return;
      }
      // 2. 没有文件缓存 → 网络下载
      _downloadPng(index, fileName);
    });
  }

  void _downloadPng(int index, String fileName) {
    _loading.add(index);
    ImageOverlay.downloadPng(fileName).then((bytes) {
      if (!mounted) return;
      _loading.remove(index);
      _fadeCtrls[index]?.dispose();
      final fc = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 500));
      _fadeCtrls[index] = fc;
      if (bytes != null) {
        PostStorage.savePng(fileName, bytes);
        setState(() {
          _pngCache[index] = bytes;
          fc.forward();
        });
      }
    });
  }

  void _close() {
    if (!mounted) return;
    if (_animCtrl.status == AnimationStatus.reverse ||
        _animCtrl.status == AnimationStatus.dismissed) return;
    _shown = false;
    setState(() {});
    _animCtrl.reverse();
  }

  Rect _fromRect() {
    final r = widget.thumbRects.length > _currentIndex
        ? widget.thumbRects[_currentIndex]
        : null;
    return r ?? widget.thumbRects[widget.initialIndex]!;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final fullRect = Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);
    final startR = _fromRect();

    final progress = _expandAnim.value;
    final rect = Rect.lerp(startR, fullRect, progress)!;

    return GestureDetector(
      onTap: () => _close(),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(color: _bgAnim.value),
          ),
          Positioned(
            left: rect.left,
            top: rect.top,
            width: rect.width,
            height: rect.height,
            child: ClipRRect(
              borderRadius: progress < 1
                  ? BorderRadius.circular(4 * (1 - progress))
                  : BorderRadius.zero,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return PageView.builder(
      controller: PageController(initialPage: widget.initialIndex),
      itemCount: widget.images.length,
      onPageChanged: (index) {
        setState(() => _currentIndex = index);
        _loadPng(index);
      },
      itemBuilder: (context, index) {
        _loadPng(index);
        final png = _pngCache[index];
        final hasPng = png != null;
        final thumb = widget.thumbnails.length > index
            ? widget.thumbnails[index]
            : null;
        final fadeCtrl = _fadeCtrls[index];

        return InteractiveViewer(
          minScale: 1.0,
          maxScale: 4.0,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              // PNG 在底部，直接显示，不参与动画
              if (hasPng)
                Align(child: Image.memory(png!, width: double.infinity, fit: BoxFit.contain)),
              // WebP 始终存在，只改透明度：无 PNG 时=1，有 PNG 时淡出
              if (thumb != null)
                Align(
                  child: Opacity(
                    opacity: hasPng
                        ? (fadeCtrl != null ? 1 - fadeCtrl.value : 0)
                        : 1,
                    child: Image.memory(thumb, width: double.infinity, fit: BoxFit.contain),
                  ),
                ),
              if (thumb == null && !hasPng)
                const Center(child: SizedBox.shrink()),
            ],
          ),
        );
      },
    );
  }
}
