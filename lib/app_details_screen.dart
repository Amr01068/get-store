import 'dart:io';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'developer_screen.dart';
import 'models/app_model.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:path_provider/path_provider.dart';
import 'services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:open_filex/open_filex.dart';
import 'package:device_apps/device_apps.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'services/download_manager.dart';

class AppDetailsScreen extends StatefulWidget {
  final AppModel app;
  final String tag;

  const AppDetailsScreen({super.key, required this.app, required this.tag});

  @override
  State<AppDetailsScreen> createState() => _AppDetailsScreenState();
}

enum InstallState { idle, pending, downloading, installing, installed, updateAvailable }

class _AppDetailsScreenState extends State<AppDetailsScreen> with WidgetsBindingObserver {
  late AppModel _currentApp;
  InstallState _installState = InstallState.idle;
  double _downloadProgress = 0.0;

  YoutubePlayerController? _youtubeController;
  String? _youtubeVideoId;
  String? _debugVideoId;
  String? _debugYoutubeUrl;
  bool _isLoadingDetails = true;
  bool _isFavorite = false;
  List<AppModel> _similarApps = [];
  List<AppModel> _trendingApps = [];
  List<AppModel> _recommendedApps = [];

  bool _isRatingSubmitting = false;
  bool _hasRated = false;
  double _currentRating = 0.0;
  bool _hasLocalApk = false;
  bool _isPageLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DownloadManager.instance.addListener(_onDownloadManagerChanged);
    _currentApp = widget.app;
    _onDownloadManagerChanged();
    _checkLocalApk();
    _debugYoutubeUrl = _currentApp.youtubeUrl;
    
    if (_currentApp.youtubeUrl != null && _currentApp.youtubeUrl!.isNotEmpty) {
      String? videoId;
      final RegExp ytRegex = RegExp(
          r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|shorts\/|watch\?v=|watch\?.+&v=))([^&?\n]{11})');
      final match = ytRegex.firstMatch(_currentApp.youtubeUrl!.trim());
      if (match != null && match.groupCount >= 1) {
        videoId = match.group(1);
        _debugVideoId = videoId;
        _youtubeVideoId = videoId;
      }
      if (videoId != null) {
        _youtubeController = YoutubePlayerController.fromVideoId(
          videoId: videoId,
          autoPlay: true,
          params: const YoutubePlayerParams(
            showControls: false,
            mute: true,
            loop: true,
            showFullscreenButton: false,
            strictRelatedVideos: true,
          ),
        );
      }
    }
    _checkFavorite();
    _checkIfRated();
    _checkInstallStatus();
    _loadFullDetails();
    _loadRelatedApps();
  }

  void _onDownloadManagerChanged() {
    final task = DownloadManager.instance.getTask(_currentApp.id);
    if (task != null && mounted) {
      setState(() {
        _downloadProgress = task.progress;
        if (task.status == DownloadStatus.downloading) {
          _installState = InstallState.downloading;
        } else if (task.status == DownloadStatus.installing) {
          _installState = InstallState.installing;
        } else if (task.status == DownloadStatus.error || task.status == DownloadStatus.idle) {
          _installState = InstallState.idle;
          _checkInstallStatus();
        }
      });
    }
  }

  @override
  void dispose() {
    DownloadManager.instance.removeListener(_onDownloadManagerChanged);
    WidgetsBinding.instance.removeObserver(this);
    _youtubeController?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkInstallStatus();
    }
  }


  void _showFullTextBottomSheet(String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content,
                        style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.6),
                      ),
                      if (title == 'لمحة عن هذا التطبيق') ...[
                        const SizedBox(height: 25),
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 15),
                        const Text(
                          'معلومات التطبيق',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 15),
                        _buildInfoRow('الإصدار', _currentApp.version.isEmpty ? '1.0.0' : _currentApp.version),
                        _buildInfoRow('تاريخ التحديث', _currentApp.updateDate.isEmpty ? 'مؤخراً' : _currentApp.updateDate),
                        _buildInfoRow('التنزيلات', _currentApp.downloadsCount.isEmpty ? '10,000+' : _currentApp.downloadsCount),
                        _buildInfoRow('مقدَّم بواسطة', _currentApp.developerName),
                        _buildInfoRow('التصنيف العمري', _currentApp.contentRating),
                      ],
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

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _checkInstallStatus() async {
    try {
      if (kIsWeb) return;
      Application? installedApp = await DeviceApps.getApp(_currentApp.packageName, true);
      if (mounted) {
        setState(() {
          if (installedApp != null) {
            String installedVersion = installedApp.versionName ?? '';
            if (_currentApp.version.isNotEmpty &&
                installedVersion.isNotEmpty &&
                _isStoreVersionNewer(installedVersion, _currentApp.version)) {
              _installState = InstallState.updateAvailable;
            } else {
              _installState = InstallState.installed;
            }
          } else {
            _installState = InstallState.idle;
            _checkLocalApk();
          }
        });
      }
    } catch (e) {
      print('Error checking install status: $e');
    }
  }

  bool _isStoreVersionNewer(String installed, String store) {
    try {
      List<int> instParts = installed.replaceAll(RegExp(r'[^0-9.]'), '').split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> storeParts = store.replaceAll(RegExp(r'[^0-9.]'), '').split('.').map((e) => int.tryParse(e) ?? 0).toList();
      int length = instParts.length > storeParts.length ? instParts.length : storeParts.length;
      for (int i = 0; i < length; i++) {
        int instVal = i < instParts.length ? instParts[i] : 0;
        int storeVal = i < storeParts.length ? storeParts[i] : 0;
        if (storeVal > instVal) return true;
        if (instVal > storeVal) return false;
      }
    } catch (_) {}
    return installed != store;
  }

  Future<void> _checkIfRated() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _hasRated = prefs.getBool('rated_${_currentApp.id}') ?? false;
        _currentRating = prefs.getDouble('rating_val_${_currentApp.id}') ?? 0.0;
      });
    }
  }

  Future<void> _submitRating(double rating) async {
    if (_isRatingSubmitting || rating == _currentRating) return;
    
    double oldRating = _currentRating;
    setState(() { 
      _isRatingSubmitting = true; 
    });
    
    final result = await ApiService.submitAppRating(_currentApp.id, rating, oldRating);
    
    if (mounted) {
      if (result['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('rated_${_currentApp.id}', true);
        await prefs.setDouble('rating_val_${_currentApp.id}', rating);
        setState(() {
          _hasRated = true;
          _currentRating = rating;
          _isRatingSubmitting = false;
          _currentApp = _currentApp.copyWith(
            rating: result['rating'],
            reviewsCount: result['reviewsCount']
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(oldRating > 0 ? 'تم تحديث تقييمك بنجاح!' : 'شكراً لتقييمك! تم إرسال التقييم بنجاح.'),
          backgroundColor: Colors.green,
        ));
      } else {
        setState(() { _isRatingSubmitting = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('حدث خطأ أثناء التقييم، الرجاء المحاولة لاحقاً.'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _checkFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isFavorite = prefs.getBool('fav_${_currentApp.id}') ?? false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isFavorite = !_isFavorite;
    });
    await prefs.setBool('fav_${_currentApp.id}', _isFavorite);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isFavorite ? 'تمت الإضافة إلى المفضلة' : 'تمت الإزالة من المفضلة'),
        backgroundColor: _isFavorite ? Colors.green : Colors.grey[800],
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _loadFullDetails() async {
    // Run related apps asynchronously in the background so it doesn't block page load
    _loadRelatedApps();

    try {
      final fullData = await ApiService.fetchAppFullDetails(_currentApp).timeout(
        const Duration(milliseconds: 1200),
        onTimeout: () => _currentApp,
      );
      if (mounted) {
        setState(() {
          _currentApp = fullData;
          _isLoadingDetails = false;
          _isPageLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
          _isPageLoading = false;
        });
      }
    }
  }

  Future<void> _loadRelatedApps() async {
    try {
      final similar = await ApiService.fetchPaginatedApps(_currentApp.name.split(' ').first, 0);
      final trending = await ApiService.fetchPaginatedApps('top', 0);
      final recommended = await ApiService.fetchSupabaseLatest();

      if (mounted) {
        setState(() {
          _similarApps = similar.where((a) => a.id != _currentApp.id).toList();
          _trendingApps = trending.where((a) => a.id != _currentApp.id).toList();
          _recommendedApps = recommended.where((a) => a.id != _currentApp.id).toList();
        });
      }
    } catch (e) {
      print('Error loading related apps: $e');
    }
  }

  Future<String?> _resolveMediaFireWithWebView(String pageUrl) async {
    String? resolvedUrl;
    String fetchUrl = pageUrl.trim();
    if (!fetchUrl.startsWith('http://') && !fetchUrl.startsWith('https://')) {
      fetchUrl = 'https://$fetchUrl';
    }

    if (!mounted) return null;

    await showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          height: 180,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                'جاري تجهيز رابط التحميل المباشر...',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'تخطى الحماية والتشفير تلقائياً...',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              SizedBox(
                height: 1,
                width: 1,
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(fetchUrl)),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    useOnDownloadStart: true,
                    useShouldOverrideUrlLoading: true,
                    userAgent: "Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
                  ),
                  onDownloadStartRequest: (controller, downloadStartRequest) {
                    final urlStr = downloadStartRequest.url.toString();
                    if (urlStr.isNotEmpty) {
                      resolvedUrl = urlStr;
                      if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                    }
                  },
                  shouldOverrideUrlLoading: (controller, navigationAction) async {
                    final reqUrl = navigationAction.request.url?.toString() ?? '';
                    if (reqUrl.contains('download') && (reqUrl.contains('mediafire.com') || reqUrl.contains('.apk'))) {
                      resolvedUrl = reqUrl;
                      if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                      return NavigationActionPolicy.CANCEL;
                    }
                    return NavigationActionPolicy.ALLOW;
                  },
                  onLoadStop: (controller, loadedUrl) async {
                    for (int i = 0; i < 4; i++) {
                      if (resolvedUrl != null) break;
                      await Future.delayed(const Duration(milliseconds: 600));
                      try {
                        final res = await controller.evaluateJavascript(source: """
                          (function() {
                            var btn = document.getElementById('downloadButton') || 
                                      document.querySelector('a[aria-label="Download file"]') || 
                                      document.querySelector('.download_link a');
                            if (btn) {
                              var href = btn.getAttribute('href');
                              if (href && href.indexOf('download') !== -1 && href.indexOf('mediafire.com') !== -1) {
                                return href;
                              }
                              btn.click();
                              return href;
                            }
                            return null;
                          })();
                        """);
                        if (res != null && res.toString().isNotEmpty && res.toString() != 'null') {
                          String hrefStr = res.toString();
                          if (hrefStr.startsWith('//')) hrefStr = 'https:$hrefStr';
                          if (hrefStr.contains('download') && hrefStr.contains('mediafire.com')) {
                            resolvedUrl = hrefStr;
                            if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                            break;
                          }
                        }
                      } catch (_) {}
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    return resolvedUrl;
  }

  Dio _createDio() {
    final dio = Dio();
    if (!kIsWeb) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (cert, host, port) => true;
          return client;
        },
      );
    }
    return dio;
  }

  void _startInstall() async {
    setState(() {
      _installState = InstallState.pending;
      _downloadProgress = 0.0;
    });
    
    // Increment downloads count in backend (non-blocking)
    ApiService.incrementAppDownloads(widget.app.id);
    
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted || _installState == InstallState.idle) return;

    final url = widget.app.apkUrl.toLowerCase();
    bool isMediaFire = url.contains('mediafire.com');
    bool isMega = url.contains('mega.nz');
    String downloadUrl = widget.app.apkUrl;

    final headers = <String, String>{
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
    };

    if (isMega) {
      setState(() { _installState = InstallState.idle; });
      if (await canLaunchUrl(Uri.parse(widget.app.apkUrl))) {
        await launchUrl(Uri.parse(widget.app.apkUrl), mode: LaunchMode.externalApplication);
      }
      return;
    }

    if (isMediaFire) {
      try {
        String fetchUrl = widget.app.apkUrl.trim();
        if (!fetchUrl.startsWith('http://') && !fetchUrl.startsWith('https://')) {
          fetchUrl = 'https://$fetchUrl';
        }

        final dio = _createDio();
        dio.options.headers = {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
        };
        dio.options.followRedirects = true;
        dio.options.maxRedirects = 5;
        dio.options.validateStatus = (status) => true;
        
        final response = await dio.get(fetchUrl);
        String htmlStr = response.data.toString();

        final RegExp regExpDirect = RegExp(r'((?:https?:)?//download\d*\.mediafire\.com/[^\s"<>]+)', caseSensitive: false);
        final match = regExpDirect.firstMatch(htmlStr);
        if (match != null && match.groupCount >= 1) {
          String ext = match.group(1)!;
          if (ext.startsWith('//')) ext = 'https:$ext';
          downloadUrl = ext;
          print('Fast Dio extracted direct link: $downloadUrl');
        } else {
          print('Dio fast extraction missed, launching WebView Modal Sheet...');
          final resolved = await _resolveMediaFireWithWebView(widget.app.apkUrl);
          if (resolved != null && resolved.isNotEmpty) {
            downloadUrl = resolved;
            print('WebView Modal Sheet resolved direct link: $downloadUrl');
          } else {
            throw Exception('تعذر استخراج رابط التحميل المباشر');
          }
        }
      } catch (e) {
        print('MediaFire extraction error: $e');
        setState(() { _installState = InstallState.idle; });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('تعذر التثبيت التلقائي: $e'),
            backgroundColor: Colors.red,
          ));
        }
        return;
      }
    }

    if (kIsWeb) {
      setState(() {
        _installState = InstallState.downloading;
      });
      for (int i = 1; i <= 100; i += 5) {
        if (!mounted || _installState != InstallState.downloading) break;
        await Future.delayed(const Duration(milliseconds: 100));
        setState(() {
          _downloadProgress = i / 100.0;
        });
      }
      
      if (!mounted) return;
      setState(() { 
        _installState = InstallState.installed; 
      });
      
      if (await canLaunchUrl(Uri.parse(downloadUrl))) {
        await launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
      }
      return;
    }
    
    setState(() {
      _installState = InstallState.downloading;
    });

    DownloadManager.instance.startDownload(_currentApp, downloadUrl, headers);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isPageLoading
          ? AppBar(
              backgroundColor: Colors.black,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _isPageLoading
            ? const Center(
                key: ValueKey('page_loading'),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    color: Color(0xFF01875F),
                    strokeWidth: 3.5,
                  ),
                ),
              )
            : KeyedSubtree(
                key: const ValueKey('page_loaded_content'),
                child: Stack(
                  children: [
                    SafeArea(
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                SliverAppBar(
                  backgroundColor: Colors.black,
                  elevation: 0,
                  pinned: true,
                  expandedHeight: 190,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          _currentApp.coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF1F1C2C), Color(0xFF928DAB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Center(
                              child: Icon(Icons.sports_esports, color: Colors.white.withOpacity(0.5), size: 64),
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.3),
                                Colors.black.withOpacity(0.8),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () {}),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      color: Colors.grey[900],
                      onSelected: (value) {
                        if (value == 'favorite') {
                          _toggleFavorite();
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'favorite',
                          child: Row(
                            children: [
                              Icon(
                                _isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: _isFavorite ? Colors.redAccent : Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Hero(
                              tag: widget.tag,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: Image.network(
                                    _currentApp.iconUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)]),
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _currentApp.name.isNotEmpty ? _currentApp.name[0].toUpperCase() : '🎮',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 36),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 5), 
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _currentApp.name,
                                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 5),
                                    InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => DeveloperScreen(app: _currentApp),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        _currentApp.developerName,
                                        style: const TextStyle(color: Colors.tealAccent, fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    if (_currentApp.containsAds || _currentApp.inAppPurchases) ...[
                                      const SizedBox(height: 5),
                                      Text(
                                        [
                                          if (_currentApp.containsAds) 'يحتوي على إعلانات',
                                          if (_currentApp.inAppPurchases) 'عمليات الشراء'
                                        ].join(' • '),
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(child: _buildStatItem(_currentApp.rating, const Icon(Icons.star, color: Colors.amber, size: 14), _currentApp.reviewsCount)),
                            _buildDivider(),
                            Expanded(child: _buildStatItem(_currentApp.downloadsCount, const Icon(Icons.file_download_outlined, color: Colors.white, size: 16), 'تنزيل')),
                            _buildDivider(),
                            Expanded(child: _buildStatItem(_currentApp.size.replaceAll(RegExp(r'\s*MB\s*|\s*م\.ب\s*', caseSensitive: false), '').trim(), const Text('MB', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)), 'الحجم')),
                            _buildDivider(),
                            Expanded(
                              child: _buildStatItem(
                                _currentApp.contentRating,
                                const Icon(Icons.verified_user_outlined, color: Colors.tealAccent, size: 15),
                                'التصنيف',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        
                        SizedBox(
                          height: 50,
                          child: _buildInstallSection(),
                        ),
                        const SizedBox(height: 18),
                        
                        // 1. وصف التطبيق (مختصر بخط احترافي وأصغر)
                        const Text(
                          'وصف التطبيق',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _currentApp.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[400], fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 12),

                        // 2. ما الجديد
                        InkWell(
                          onTap: () => _showFullTextBottomSheet('ما الجديد', _currentApp.whatsNew),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: const [
                                    Text('ما الجديد', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                    Icon(Icons.arrow_forward, color: Colors.white70, size: 16),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  _currentApp.whatsNew,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // 3. الصور (Screenshots)
                        if (_isLoadingDetails)
                          const Center(child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(color: Colors.teal),
                          ))
                        else if (_currentApp.screenshots.isNotEmpty) ...[
                          SizedBox(
                            height: 220,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: _currentApp.screenshots.length,
                              itemBuilder: (context, index) {
                                return Stack(
  fit: StackFit.passthrough,
  children: [
    Container(
                                    width: 120,
                                    margin: const EdgeInsets.only(left: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[800],
                                      borderRadius: BorderRadius.circular(12),
                                      image: DecorationImage(
                                        image: NetworkImage(_currentApp.screenshots[index]),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
    Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => FullScreenGallery(
                                          images: _currentApp.screenshots,
                                          initialIndex: index,
                                        ),
                                      ),
                                    );
                                  },
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  ],
);
                              },
                            ),
                          ),
                          const SizedBox(height: 25),
                        ],
                        
                        // 4. لمحة عن هذا التطبيق (تحت السكرين شوتس)
                        InkWell(
                          onTap: () => _showFullTextBottomSheet('لمحة عن هذا التطبيق', _currentApp.description),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: const [
                                    Text('لمحة عن هذا التطبيق', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                    Icon(Icons.arrow_forward, color: Colors.white, size: 18), 
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _currentApp.description,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),
                        
                        // 5. قيم هذا التطبيق (دائم ولا يختفي ويمكن تحديثه)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('قيم هذا التطبيق', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                if (_hasRated)
                                  Text(
                                    'تقييمك: ${_currentRating.toStringAsFixed(1)} ⭐',
                                    style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _hasRated ? 'انقر على النجوم لتحديث تقييمك في أي وقت' : 'مشاركتك تهمنا! اختر التقييم المناسب',
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: RatingBar.builder(
                                initialRating: _currentRating,
                                minRating: 1,
                                direction: Axis.horizontal,
                                allowHalfRating: true,
                                itemCount: 5,
                                itemPadding: const EdgeInsets.symmetric(horizontal: 6.0),
                                itemBuilder: (context, _) => const Icon(Icons.star_rounded, color: Colors.amber, size: 32),
                                onRatingUpdate: (rating) {
                                  _submitRating(rating);
                                },
                              ),
                            ),
                            const SizedBox(height: 25),
                          ],
                        ),
                          
                        if (_similarApps.isNotEmpty) ...[
                          const Text('تطبيقات مشابهة', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 150,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _similarApps.length,
                              itemBuilder: (context, index) {
                                final app = _similarApps[index];
                                return GestureDetector(
                                  onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AppDetailsScreen(app: app, tag: 'similar_${app.id}'))),
                                  child: Container(
                                    width: 100,
                                    margin: const EdgeInsets.only(left: 15),
                                    child: Column(
                                      children: [
                                        Hero(
                                          tag: 'similar_${app.id}',
                                          child: Container(
                                            width: 80, height: 80,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(15),
                                              image: DecorationImage(image: NetworkImage(app.iconUrl), fit: BoxFit.cover),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 15),
                        ],

                        // 6. حائط إعلاني (AdMob Banner Placeholder)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 10, bottom: 20),
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.grey[900]!,
                                Colors.grey[850]!,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.ad_units_outlined, color: Colors.tealAccent.withOpacity(0.7), size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'حائط إعلاني',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildStatItem(dynamic topValue, Widget icon, dynamic bottomValue) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(topValue.toString(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(width: 3),
            icon,
          ],
        ),
        const SizedBox(height: 4),
        Text(
          bottomValue.toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 25,
      color: Colors.white12,
    );
  }

  CancelToken? _cancelToken;

  void _cancelDownload() {
    DownloadManager.instance.cancelDownload(_currentApp.id);
    if (mounted) {
      setState(() {
        _installState = InstallState.idle;
        _downloadProgress = 0.0;
      });
    }
  }

  Future<void> _checkLocalApk() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${_currentApp.id}.apk');
      if (await file.exists()) {
        final size = await file.length();
        if (size > 1000 && mounted) {
          setState(() {
            _hasLocalApk = true;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _deleteLocalApk() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${_currentApp.id}.apk');
      if (await file.exists()) {
        await file.delete();
      }
      if (mounted) {
        setState(() {
          _hasLocalApk = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم حذف ملف الـ APK من المخزون بنجاح'),
          backgroundColor: Colors.teal,
        ));
      }
    } catch (_) {}
  }

  Widget _buildInstallSection() {
    if (_currentApp.status == 'coming_soon' || _currentApp.status == 'locked') {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'هذا التطبيق قيد التطوير ولم يصدر بعد! ترقبوا توفيره قريباً في GET STORE',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
                backgroundColor: Color(0xFFD97706),
                duration: Duration(seconds: 3),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            minimumSize: const Size(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          ),
          child: const Text(
            'قريباً',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Cairo',
            ),
          ),
        ),
      );
    }

    if (_installState == InstallState.updateAvailable) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _startInstall,
              icon: const Icon(Icons.system_update_alt, color: Colors.white, size: 20),
              label: const Text('تحديث', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF01875F),
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                try {
                  final intent = AndroidIntent(
                    action: 'android.intent.action.DELETE',
                    data: 'package:${widget.app.packageName}',
                  );
                  await intent.launch();
                } catch (e) {
                  print('Failed to uninstall app: $e');
                }
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: const Text('إلغاء التثبيت', style: TextStyle(color: Colors.redAccent, fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    } else if (_installState == InstallState.installed) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                try {
                  await DeviceApps.openApp(widget.app.packageName);
                } catch (e) {
                  print('Failed to open app: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: const Text('فتح', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                try {
                  final intent = AndroidIntent(
                    action: 'android.intent.action.DELETE',
                    data: 'package:${widget.app.packageName}',
                  );
                  await intent.launch();
                } catch (e) {
                  print('Failed to uninstall app: $e');
                }
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: const Text('إلغاء التثبيت', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    } else if (_installState == InstallState.pending ||
        _installState == InstallState.downloading ||
        _installState == InstallState.installing) {
      final percentage = (_downloadProgress * 100).clamp(0, 100).toStringAsFixed(0);
      
      String statusText;
      if (_installState == InstallState.pending) {
        statusText = 'يرجى الانتظار...';
      } else if (_installState == InstallState.downloading) {
        statusText = 'جاري التنزيل...';
      } else {
        statusText = 'جاري التثبيت...';
      }

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        statusText,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      if (_installState == InstallState.downloading)
                        Text(
                          '$percentage%',
                          style: const TextStyle(color: Color(0xFF01875F), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _installState == InstallState.downloading ? (_downloadProgress > 0 ? _downloadProgress : null) : null,
                      minHeight: 5,
                      color: const Color(0xFF01875F),
                      backgroundColor: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _cancelDownload,
              icon: const Icon(Icons.close, color: Colors.white70, size: 20),
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'إلغاء',
            ),
          ],
        ),
      );
    } else if (_hasLocalApk) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                final dir = await getTemporaryDirectory();
                final savePath = '${dir.path}/${_currentApp.id}.apk';
                OpenFilex.open(savePath);
              },
              icon: const Icon(Icons.download_done, color: Colors.white, size: 20),
              label: const Text('تثبيت', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF01875F),
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _deleteLocalApk,
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              label: const Text('حذف الملف', style: TextStyle(color: Colors.redAccent, fontSize: 15, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
            ),
          ),
        ],
      );
    } else {
      return ElevatedButton(
        onPressed: _startInstall,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF01875F),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          elevation: 2,
        ),
        child: const Text('تنزيل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      );
    }
  }
}

class FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const FullScreenGallery({super.key, required this.images, required this.initialIndex});

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        itemBuilder: (context, index) {
          return InteractiveViewer(
            child: Center(
              child: Image.network(widget.images[index]),
            ),
          );
        },
      ),
    );
  }
}
