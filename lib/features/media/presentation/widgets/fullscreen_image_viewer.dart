import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FullscreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullscreenImageViewer({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
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
      if (mounted) {
        _focusNode.requestFocus();
      }
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
        throw Exception('No data received from download request');
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
            } catch (e, stack) {
              developer.log(
                'Direct file write failed after picker (plugin may have written it): $e',
                error: e,
                stackTrace: stack,
              );
            }
          }
        }
      } else {
        final appDocDir = await getApplicationDocumentsDirectory();
        savePath = p.join(appDocDir.path, fileName);
        final file = File(savePath);
        await file.writeAsBytes(bytes);
      }

      if (savePath != null && mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(l10n.detailsGalleryDownloadSuccess),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    } catch (e, stack) {
      developer.log(
        'Failed to download gallery image from $url',
        error: e,
        stackTrace: stack,
      );
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('${l10n.detailsGalleryDownloadFailed}: $e'),
            backgroundColor: AppTheme.favorites,
          ),
        );
      }
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
                    icon: const Icon(Icons.arrow_back, color: AppTheme.textWhite, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  // Indicator: e.g. "3 / 15"
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceOverlay,
                      borderRadius: AppTheme.radiusLg,
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.imageUrls.length}',
                      style: const TextStyle(
                        color: AppTheme.textWhite,
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
                          icon: const Icon(Icons.download, color: AppTheme.textWhite, size: 28),
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
            ? AppTheme.primary.withValues(alpha: 0.6)
            : AppTheme.primary.withValues(alpha: 0.2));
    final borderColor = showHoverEffects
        ? AppTheme.accent
        : (isEnabled
            ? AppTheme.textWhite.withValues(alpha: 0.15)
            : AppTheme.textWhite.withValues(alpha: 0.05));
    final iconColor = showHoverEffects
        ? AppTheme.accent
        : (isEnabled
            ? AppTheme.textWhite
            : AppTheme.textWhite.withValues(alpha: 0.25));
    final shadowColor = showHoverEffects
        ? AppTheme.accent.withValues(alpha: 0.2)
        : (isEnabled
            ? AppTheme.primary.withValues(alpha: 0.4)
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
              borderRadius: AppTheme.radiusFull,
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
            errorWidget: (context, url, error) => Center(
              child: Icon(
                Icons.broken_image,
                color: AppTheme.textWhite.withValues(alpha: 0.24),
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
