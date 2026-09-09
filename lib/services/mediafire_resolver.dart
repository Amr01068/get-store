import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class MediaFireResolver {
  /// Headless WebView resolver for MediaFire and protected download links.
  static Future<String?> resolveDirectLink(String pageUrl) async {
    if (kIsWeb) {
      return null;
    }

    final completer = Completer<String?>();
    HeadlessInAppWebView? headlessWebView;
    Timer? timeoutTimer;

    void tryComplete(String url) {
      if (url.isEmpty || completer.isCompleted) return;
      
      // التأكد أن الرابط هو رابط تحميل مباشر من ميديا فاير أو ملف apk
      if (url.contains('download') && (url.contains('mediafire.com') || url.endsWith('.apk') || url.contains('.apk?'))) {
        print('MediaFireResolver captured direct URL: $url');
        completer.complete(url);
      }
    }

    try {
      headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(pageUrl)),
        initialSettings: InAppWebViewSettings(
          userAgent:
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36",
          javaScriptEnabled: true,
          useOnDownloadStart: true,
          useShouldOverrideUrlLoading: true,
          mediaPlaybackRequiresUserGesture: false,
          allowFileAccessFromFileURLs: true,
          javaScriptCanOpenWindowsAutomatically: true,
        ),
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          final url = navigationAction.request.url?.toString() ?? '';
          print('HeadlessWebView navigating to: $url');
          if (url.contains('download') && url.contains('mediafire.com')) {
            tryComplete(url);
            return NavigationActionPolicy.CANCEL;
          }
          return NavigationActionPolicy.ALLOW;
        },
        onDownloadStartRequest: (controller, downloadStartRequest) {
          final urlStr = downloadStartRequest.url.toString();
          print('HeadlessWebView caught download start: $urlStr');
          tryComplete(urlStr);
        },
        onLoadStart: (controller, url) {
          final urlStr = url?.toString() ?? '';
          print('HeadlessWebView load start: $urlStr');
          tryComplete(urlStr);
        },
        onLoadStop: (controller, url) async {
          final currentUrl = url?.toString() ?? '';
          print('HeadlessWebView finished loading: $currentUrl');
          tryComplete(currentUrl);

          // نقوم بعمل المحاولات للضغط والنقر على الزر برمجياً
          for (int i = 0; i < 6; i++) {
            if (completer.isCompleted) break;
            await Future.delayed(const Duration(milliseconds: 1000));

            try {
              final result = await controller.evaluateJavascript(source: """
                (function() {
                  var btn = document.getElementById('downloadButton') || 
                            document.querySelector('a[aria-label="Download file"]') || 
                            document.querySelector('.download_link a.input') ||
                            document.querySelector('a[href*="download"]');
                  if (btn) {
                    var href = btn.getAttribute('href');
                    // إذا كان الرابط مكتمل ومباشر من البداية
                    if (href && href.indexOf('download') !== -1 && href.indexOf('mediafire.com') !== -1) {
                      return href;
                    }
                    // محاكاة النقر على الزر لتوليد الرابط وتفعيل التنزيل
                    btn.click();
                    return href;
                  }
                  return null;
                })();
              """);

              if (result != null && result.toString().isNotEmpty && result.toString() != 'null') {
                String directUrl = result.toString();
                if (directUrl.startsWith('//')) {
                  directUrl = 'https:$directUrl';
                }
                print('HeadlessWebView JS evaluated href: $directUrl');
                tryComplete(directUrl);
              }
            } catch (e) {
              print('JS eval error: $e');
            }
          }
        },
      );

      await headlessWebView.run();

      // مهلة زمنية 12 ثانية
      timeoutTimer = Timer(const Duration(seconds: 12), () {
        if (!completer.isCompleted) {
          print('HeadlessWebView timed out without finding direct link');
          completer.complete(null);
        }
      });

      final directLink = await completer.future;
      return directLink;
    } catch (e) {
      print('HeadlessWebView resolver error: $e');
      return null;
    } finally {
      timeoutTimer?.cancel();
      try {
        await headlessWebView?.dispose();
      } catch (_) {}
    }
  }
}
