import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class AppBrowser extends StatefulWidget {
  final String url;
  final String title;

  const AppBrowser({
    super.key,
    required this.url,
    required this.title,
  });

  static Future<void> show(BuildContext context, {
    required String url,
    required String title,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Browser',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return AppBrowser(url: url, title: title);
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(anim1),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<AppBrowser> createState() => _AppBrowserState();
}

class _AppBrowserState extends State<AppBrowser> {
  InAppWebViewController? webViewController;
  double progress = 0;
  bool canGoBack = false;
  bool canGoForward = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.border.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withOpacity(0.5),
                  border: Border(
                    bottom: BorderSide(color: AppTheme.border.withOpacity(0.1)),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: AppTheme.textWhite),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: AppTheme.textWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            widget.url,
                            style: TextStyle(
                              color: AppTheme.textWhite.withOpacity(0.5),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        LucideIcons.chevronLeft, 
                        color: canGoBack ? AppTheme.textWhite : AppTheme.textWhite.withOpacity(0.2)
                      ),
                      onPressed: canGoBack ? () => webViewController?.goBack() : null,
                    ),
                    IconButton(
                      icon: Icon(
                        LucideIcons.chevronRight, 
                        color: canGoForward ? AppTheme.textWhite : AppTheme.textWhite.withOpacity(0.2)
                      ),
                      onPressed: canGoForward ? () => webViewController?.goForward() : null,
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.rotateCw, color: AppTheme.textWhite, size: 20),
                      onPressed: () => webViewController?.reload(),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.externalLink, color: AppTheme.textWhite, size: 20),
                      onPressed: () => launchUrl(Uri.parse(widget.url)),
                      tooltip: 'Open in Browser',
                    ),
                  ],
                ),
              ),
              
              // Progress Bar
              if (progress < 1.0)
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.transparent,
                  color: AppTheme.accent,
                  minHeight: 2,
                ),

              // WebView
              Expanded(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri(widget.url),
                  ),
                  initialSettings: InAppWebViewSettings(
                    transparentBackground: true,
                    supportZoom: true,
                    useHybridComposition: true,
                    allowsInlineMediaPlayback: true,
                    mediaPlaybackRequiresUserGesture: false,
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    databaseEnabled: true,
                    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                  ),
                  onWebViewCreated: (controller) {
                    webViewController = controller;
                  },
                  onProgressChanged: (controller, progress) {
                    setState(() {
                      this.progress = progress / 100;
                    });
                  },
                  onLoadStop: (controller, url) async {
                    final back = await controller.canGoBack();
                    final forward = await controller.canGoForward();
                    setState(() {
                      canGoBack = back;
                      canGoForward = forward;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
