import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class GalleryBottomSheet extends StatelessWidget {
  final List<dynamic> backdrops;
  final List<dynamic> posters;
  final List<dynamic> logos;
  final int initialTabIndex;

  const GalleryBottomSheet({
    super.key,
    required this.backdrops,
    required this.posters,
    required this.logos,
    required this.initialTabIndex,
  });

  /// Static helper to launch the bottom sheet
  static void show({
    required BuildContext context,
    required List<dynamic> backdrops,
    required List<dynamic> posters,
    required List<dynamic> logos,
    required int initialTabIndex,
  }) {
    AppBottomSheet.show(
      context: context,
      heightFactor: 0.85,
      child: AppBottomSheet(
        blurSigma: 10.0,
        backgroundColor: AppTheme.primary.withValues(alpha: 0.95),
        showHandle: true,
        padding: const EdgeInsets.only(top: 8),
        child: GalleryBottomSheet(
          backdrops: backdrops,
          posters: posters,
          logos: logos,
          initialTabIndex: initialTabIndex,
        ),
      ),
    );
  }

  String _getImageUrl(dynamic item, String size) {
    if (item == null) return '';
    final path = item is Map ? item['file_path'] as String? : item.toString();
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return 'https://image.tmdb.org/t/p/$size$path';
  }

  void _openFullscreenViewer(
    BuildContext context,
    List<dynamic> items,
    int initialIndex,
  ) {
    final urls = items.map((item) => _getImageUrl(item, 'original')).toList();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.95),
        pageBuilder: (context, _, __) => _FullscreenImageViewer(
          imageUrls: urls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 3,
      initialIndex: initialTabIndex,
      child: Column(
        children: [
          TabBar(
            indicatorColor: AppTheme.accent,
            labelColor: AppTheme.textWhite,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: l10n.detailsBackdrops),
              Tab(text: l10n.detailsPosters),
              Tab(text: l10n.detailsLogos),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              children: [
                _buildGrid(
                  context: context,
                  items: backdrops,
                  crossAxisCount: 2,
                  aspectRatio: 16 / 9,
                  previewSize: 'w780',
                ),
                _buildGrid(
                  context: context,
                  items: posters,
                  crossAxisCount: 3,
                  aspectRatio: 2 / 3,
                  previewSize: 'w500',
                ),
                _buildLogoGrid(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid({
    required BuildContext context,
    required List<dynamic> items,
    required int crossAxisCount,
    required double aspectRatio,
    required String previewSize,
  }) {
    if (items.isEmpty) {
      return _buildEmptyState(context);
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final url = _getImageUrl(items[index], previewSize);
        return GestureDetector(
          onTap: () => _openFullscreenViewer(context, items, index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.white.withValues(alpha: 0.05),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.white.withValues(alpha: 0.05),
                child: const Icon(
                  Icons.broken_image,
                  color: Colors.white24,
                  size: 24,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogoGrid(BuildContext context) {
    if (logos.isEmpty) {
      return _buildEmptyState(context);
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: logos.length,
      itemBuilder: (context, index) {
        final url = _getImageUrl(logos[index], 'w500');
        return GestureDetector(
          onTap: () => _openFullscreenViewer(context, logos, index),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Center(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (context, url) => const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.accent,
                  ),
                ),
                errorWidget: (context, url, error) => const Icon(
                  Icons.broken_image,
                  color: Colors.white24,
                  size: 24,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            color: AppTheme.textMuted,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.detailsNoImages,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _FullscreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullscreenImageViewer({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  final FocusNode _focusNode = FocusNode();
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _downloadImage(String url) async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
    });

    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(url);
    final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'image.jpg';

    try {
      final response = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data;
      if (bytes == null) {
        throw Exception('No data received');
      }

      String? savePath;
      if (Platform.isWindows || Platform.isAndroid || Platform.isMacOS || Platform.isLinux) {
        savePath = await FilePicker.saveFile(
          dialogTitle: l10n.detailsGalleryDownload,
          fileName: fileName,
          bytes: Uint8List.fromList(bytes),
        );

        if (savePath != null) {
          final file = File(savePath);
          if (!savePath.startsWith('content://')) {
            try {
              if (!await file.exists() || (await file.length()) == 0) {
                await file.writeAsBytes(bytes);
              }
            } catch (_) {
              // Ignore direct write failure if plugin handled it
            }
          }
        }
      } else {
        final appDocDir = await getApplicationDocumentsDirectory();
        savePath = p.join(appDocDir.path, fileName);
        final file = File(savePath);
        await file.writeAsBytes(bytes);
      }

      if (savePath != null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(l10n.detailsGalleryDownloadSuccess),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('${l10n.detailsGalleryDownloadFailed}: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      descendantsAreFocusable: false,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowLeft) {
            if (_currentIndex > 0) {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.arrowRight) {
            if (_currentIndex < widget.imageUrls.length - 1) {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Swipeable view
            PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return _ZoomableImage(imageUrl: widget.imageUrls[index]);
              },
            ),
            // Navigation arrow - Left
            if (widget.imageUrls.length > 1)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: _NavigationArrow(
                    isLeft: true,
                    onTap: _currentIndex > 0
                        ? () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                  ),
                ),
              ),
            // Navigation arrow - Right
            if (widget.imageUrls.length > 1)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 24),
                  child: _NavigationArrow(
                    isLeft: false,
                    onTap: _currentIndex < widget.imageUrls.length - 1
                        ? () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                  ),
                ),
              ),
            // Top controls bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  // Indicator: e.g. "3 / 15"
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.imageUrls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Download Button
                  _isDownloading
                      ? const SizedBox(
                          width: 48,
                          height: 48,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.accent,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.download, color: Colors.white, size: 28),
                          tooltip: l10n.detailsGalleryDownload,
                          onPressed: () => _downloadImage(widget.imageUrls[_currentIndex]),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationArrow extends StatefulWidget {
  final bool isLeft;
  final VoidCallback? onTap;

  const _NavigationArrow({
    required this.isLeft,
    required this.onTap,
  });

  @override
  State<_NavigationArrow> createState() => _NavigationArrowState();
}

class _NavigationArrowState extends State<_NavigationArrow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tooltipMessage = widget.isLeft ? l10n.detailsGalleryPrevious : l10n.detailsGalleryNext;
    final isEnabled = widget.onTap != null;
    final showHoverEffects = isEnabled && _isHovered;

    final scale = showHoverEffects ? 1.1 : 1.0;
    final backgroundColor = showHoverEffects
        ? AppTheme.accent.withValues(alpha: 0.25)
        : (isEnabled
            ? Colors.black.withValues(alpha: 0.4)
            : Colors.black.withValues(alpha: 0.15));
    final borderColor = showHoverEffects
        ? AppTheme.accent
        : (isEnabled
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05));
    final iconColor = showHoverEffects
        ? AppTheme.accent
        : (isEnabled
            ? Colors.white
            : Colors.white.withValues(alpha: 0.25));
    final shadowColor = showHoverEffects
        ? AppTheme.accent.withValues(alpha: 0.2)
        : (isEnabled
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.transparent);
    final blurRadius = showHoverEffects ? 16.0 : (isEnabled ? 12.0 : 0.0);
    final spreadRadius = showHoverEffects ? 3.0 : (isEnabled ? 2.0 : 0.0);

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: isEnabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: isEnabled ? (_) => setState(() => _isHovered = false) : null,
      child: Tooltip(
        message: isEnabled ? tooltipMessage : '',
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(28),
              hoverColor: Colors.transparent,
              splashColor: isEnabled ? AppTheme.accent.withValues(alpha: 0.3) : null,
              highlightColor: isEnabled ? AppTheme.accent.withValues(alpha: 0.2) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: backgroundColor,
                  border: Border.all(
                    color: borderColor,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: blurRadius,
                      spreadRadius: spreadRadius,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    widget.isLeft ? Icons.chevron_left : Icons.chevron_right,
                    color: iconColor,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  final String imageUrl;

  const _ZoomableImage({required this.imageUrl});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  late TransformationController _transformationController;
  TapDownDetails? _doubleTapDetails;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_handleTransformationChanged);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_handleTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _handleTransformationChanged() {
    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final isZoomed = scale > 1.001;
    if (isZoomed != _isZoomed) {
      setState(() {
        _isZoomed = isZoomed;
      });
    }
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails!.localPosition;
      _transformationController.value = Matrix4.identity()
        ..translateByVector3(Vector3(-position.dx * 1.5, -position.dy * 1.5, 0.0))
        ..scaleByVector3(Vector3(2.5, 2.5, 1.0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        maxScale: 4.0,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: widget.imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: AppTheme.accent,
                ),
              ),
            ),
            errorWidget: (context, url, error) => const Center(
              child: Icon(
                Icons.broken_image,
                color: Colors.white24,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
