import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_details_screen.dart';
import 'models/app_model.dart';
import 'services/api_service.dart';
import 'permissions_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/download_manager.dart';

import 'storage_vault_screen.dart';
import 'nominations_screen.dart';
import 'models/nomination_model.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  await Supabase.initialize(
    url: 'https://clzgnklxjrydblnkugkw.supabase.co',
    publishableKey: 'sb_publishable_1U4qHtiyjbBeCOAxRiLbPQ_QdXOpSzu',
  );
  
  await DownloadManager.instance.initNotifications();
  
  final prefs = await SharedPreferences.getInstance();
  final hasSeenPermissions = prefs.getBool('has_seen_permissions') ?? false;
  
  runApp(GetStoreApp(hasSeenPermissions: hasSeenPermissions));
}

class GetStoreApp extends StatelessWidget {
  final bool hasSeenPermissions;
  const GetStoreApp({super.key, required this.hasSeenPermissions});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GET Store',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.unknown
        },
      ),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
        useMaterial3: true,
        fontFamily: GoogleFonts.notoSansArabic().fontFamily,
        textTheme: GoogleFonts.notoSansArabicTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: hasSeenPermissions ? const MainScreen() : const PermissionsScreen(),
    );
  }
}

class CategoryConfig {
  final String title;
  final String query;
  const CategoryConfig(this.title, this.query);
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String _selectedCategory = 'موصى به لك';
  final List<String> _categories = ['موصى به لك', 'أهم التطبيقات المجانية', 'للأطفال', 'مميز'];
  
  List<AppModel> _allBanners = [];
  List<AppModel> _appBanners = [];
  List<AppModel> _gameBanners = [];
  List<AppModel> _supabaseLatest = [];
  List<AppModel> _topDownloadedApps = [];
  List<NominationModel> _activeNominations = [];
  bool _isLoadingBanners = true;
  bool _isLoadingLatest = true;
  bool _isLoadingTopDownloaded = true;
  bool _isLoadingNominations = true;
  int _currentBannerPage = 0;
  
  Timer? _bannerTimer;
  final PageController _bannerController = PageController(viewportFraction: 0.9);

  final List<CategoryConfig> _appCategories = const [
    CategoryConfig('موصى به لك', 'app'),
    CategoryConfig('أدوات وبرامج', 'app tools أدوات'),
    CategoryConfig('تطبيقات إنتاجية', 'app productivity إنتاجية'),
    CategoryConfig('تواصل اجتماعي', 'app social تواصل'),
    CategoryConfig('تعليم وثقافة', 'app education تعليم'),
    CategoryConfig('تسالي وترفيه', 'app entertainment ترفيه'),
  ];

  final List<CategoryConfig> _gameCategories = const [
    CategoryConfig('ألعاب رائجة ومميزة', 'game'),
    CategoryConfig('ألعاب أكشن وإثارة', 'game action أكشن'),
    CategoryConfig('ألعاب سباق وسرعة', 'game racing سباق'),
    CategoryConfig('ألعاب ذكاء وألغاز', 'game puzzle ألغاز'),
    CategoryConfig('ألعاب استراتيجية', 'game strategy استراتيجية'),
    CategoryConfig('ألعاب رياضية', 'game sports رياضة'),
  ];

  final List<CategoryConfig> _allCategories = const [
    CategoryConfig('أحدث الإضافات', 'new'),
    CategoryConfig('أشهر التطبيقات', 'app'),
    CategoryConfig('أشهر الألعاب', 'game'),
    CategoryConfig('أدوات النظام والإنتاجية', 'tools productivity'),
    CategoryConfig('ألعاب الحركة والذكاء', 'action puzzle'),
  ];

  @override
  void initState() {
    super.initState();
    _loadBanners();
    _loadSupabaseLatest();
    _loadTopDownloadedApps();
    _loadActiveNominations();
    _startBannerTimer();
  }

  Future<void> _loadActiveNominations() async {
    try {
      final noms = await ApiService.fetchActiveNominations();
      if (mounted) {
        setState(() {
          _activeNominations = noms;
          _isLoadingNominations = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingNominations = false);
    }
  }



  Future<void> _loadSupabaseLatest() async {
    try {
      final latest = await ApiService.fetchSupabaseLatest();
      if (mounted) {
        setState(() {
          _supabaseLatest = latest;
          _isLoadingLatest = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLatest = false);
    }
  }

  Future<void> _loadTopDownloadedApps() async {
    try {
      final apps = await ApiService.fetchTopDownloadedApps();
      if (mounted) {
        setState(() {
          _topDownloadedApps = apps;
          _isLoadingTopDownloaded = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTopDownloaded = false);
    }
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_bannerController.hasClients) {
        final currentBanners = _selectedIndex == 0 ? _allBanners :
                               _selectedIndex == 2 ? _gameBanners : _appBanners;
        if (currentBanners.length <= 1) return;

        int currentPage = _bannerController.page?.round() ?? _currentBannerPage;
        int nextPage = (currentPage + 1) % currentBanners.length;

        _bannerController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 750),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _resetBannerTimer() {
    _startBannerTimer();
  }

  Future<void> _loadBanners() async {
    try {
      final allFeatured = await ApiService.fetchTopFeaturedBanners(type: 'all');
      final appFeatured = await ApiService.fetchTopFeaturedBanners(type: 'apps');
      final gameFeatured = await ApiService.fetchTopFeaturedBanners(type: 'games');
      if (mounted) {
        setState(() {
          _allBanners = allFeatured;
          _appBanners = appFeatured.isNotEmpty ? appFeatured : allFeatured;
          _gameBanners = gameFeatured.isNotEmpty ? gameFeatured : allFeatured;
          _isLoadingBanners = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingBanners = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCategories = _selectedIndex == 0 ? _allCategories : 
                             _selectedIndex == 1 ? _appCategories : _gameCategories;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _selectedIndex == 3
            ? _buildMoreTab()
            : CustomScrollView(
                physics: const BouncingScrollPhysics(), 
                slivers: [
                  _buildAppBar(),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),

                        _buildBanners(),
                        const SizedBox(height: 16),
                        if (_selectedIndex == 0) ...[
                          _buildNominationsShowcase(),
                          const SizedBox(height: 20),
                        ],
                        if (_selectedIndex == 0 && (_supabaseLatest.isNotEmpty || _isLoadingLatest))
                          _buildLatestProductsDrawer(),
                        if (_selectedIndex == 0) const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == activeCategories.length) {
                          return _buildSectionTitle('اكتشاف المزيد', showArrow: true, onTap: () {
                            String discoverQuery = _selectedIndex == 1 ? 'apps tools' : 'games action';
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DiscoverMoreScreen(initialApps: const [], query: discoverQuery),
                              ),
                            );
                          });
                        }
                        return Column(
                          children: [
                            CategorySection(
                              key: ValueKey(activeCategories[index].title),
                              config: activeCategories[index],
                            ),
                            if (_selectedIndex == 0 && activeCategories[index].title == 'الأكثر تحميلاً')
                              _buildTopDownloadsGrid(),
                          ],
                        );
                      },
                      childCount: activeCategories.length + 1,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 30)),
                ],
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          if (_bannerController.hasClients) {
            _bannerController.jumpToPage(0);
          }
          _resetBannerTimer();
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        selectedItemColor: Colors.tealAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.category), label: 'الكل'),
          BottomNavigationBarItem(icon: Icon(Icons.apps), label: 'تطبيقات'),
          BottomNavigationBarItem(icon: Icon(Icons.videogame_asset), label: 'ألعاب'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'المزيد'),
        ],
      ),
    );
  }

  Widget _buildMoreTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'المزيد',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StorageVaultScreen()),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.folder_special_outlined, color: Colors.tealAccent, size: 28),
                            SizedBox(width: 10),
                            Text(
                              'المخزون',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'تطبيقاتك المحمّلة محلياً والمعلقة للتثبيت',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NominationsScreen()),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.how_to_vote_rounded, color: Colors.tealAccent, size: 28),
                            SizedBox(width: 10),
                            Text(
                              'ترشيحات واستطلاع الرأي',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'صوّت لتطبيقاتك وألعابك المفضلة للمطورين',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.black,
      elevation: 0,
      title: InkWell(
        onTap: () {
          showSearch(context: context, delegate: AppSearchDelegate());
        },
        borderRadius: BorderRadius.circular(25),
        child: Container(
          height: 45,
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 15),
                child: Icon(Icons.search, color: Colors.grey),
              ),
              const Expanded(
                child: Text(
                  'البحث عن التطبيقات والألعاب',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
              Container(
                margin: const EdgeInsets.all(5),
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.teal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ),
      leadingWidth: 55,
      leading: Padding(
        padding: const EdgeInsets.only(right: 15, top: 5, bottom: 5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset('assets/app_icon.png', fit: BoxFit.cover),
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'ترشيحات واستطلاع الرأي',
          icon: const Icon(Icons.poll_rounded, color: Colors.tealAccent),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NominationsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNominationsShowcase() {
    if (_isLoadingNominations) {
      return Container(
        height: 180,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E242B),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.tealAccent),
        ),
      );
    }

    if (_activeNominations.isEmpty) {
      return const SizedBox.shrink();
    }

    final nomination = _activeNominations.first;
    final totalVotes = nomination.totalVotes;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E222B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Badge + Action
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF01875F).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF01875F).withValues(alpha: 0.35)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.how_to_vote_outlined, size: 14, color: Color(0xFF00B074)),
                        SizedBox(width: 5),
                        Text(
                          'ترشيحات المجتمع',
                          style: TextStyle(
                            color: Color(0xFF00B074),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NominationsScreen()),
                      ).then((_) => _loadActiveNominations());
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        children: [
                          Text(
                            'عرض الكل',
                            style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Cairo'),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios, size: 11, color: Colors.grey[400]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Nomination Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                nomination.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Horizontal Candidates Row
            SizedBox(
              height: 175,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: nomination.candidates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final cand = nomination.candidates[index];
                  final isGame = cand.type == 'game';
                  final percent = totalVotes > 0 ? ((cand.votes / totalVotes) * 100).round() : 0;

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CandidateDetailsScreen(candidate: cand),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 115,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF262B35),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Candidate Image
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: buildAppImage(
                                  cand.image,
                                  width: 65,
                                  height: 65,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 65,
                                    height: 65,
                                    color: Colors.grey[800],
                                    child: Icon(
                                      isGame ? Icons.videogame_asset : Icons.apps,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: -5,
                                right: -3,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: isGame ? const Color(0xFFD97706) : const Color(0xFF01875F),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isGame ? 'لعبة' : 'تطبيق',
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Candidate Name
                          Text(
                            cand.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Percentage / Votes pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                            ),
                            child: Text(
                              '$percent% (${cand.votes})',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 14),

            // Bottom Call-To-Action Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NominationsScreen()),
                    ).then((_) => _loadActiveNominations());
                  },
                  icon: const Icon(Icons.how_to_vote, size: 18, color: Colors.white),
                  label: const Text(
                    'صوّت في هذا الاستفتاء الآن',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF01875F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

    Widget _buildTopDownloadsGrid() {
    if (_isLoadingTopDownloaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }
    
    if (_topDownloadedApps.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        _buildSectionTitle('الأعلى تحميل خلال 7 أيام', showArrow: false, onTap: null),
        SizedBox(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: (_topDownloadedApps.length / 3).ceil(),
            itemBuilder: (context, columnIndex) {
              int startIndex = columnIndex * 3;
              int endIndex = startIndex + 3;
              if (endIndex > _topDownloadedApps.length) endIndex = _topDownloadedApps.length;
              List<AppModel> columnApps = _topDownloadedApps.sublist(startIndex, endIndex);

              return Container(
                width: MediaQuery.of(context).size.width * 0.88,
                padding: EdgeInsets.only(right: columnIndex == 0 ? 15 : 0, left: 15),
                child: Column(
                  children: columnApps.asMap().entries.map((entry) {
                    int rowIndex = entry.key;
                    AppModel app = entry.value;
                    int globalIndex = startIndex + rowIndex + 1;

                    return Expanded(
                      child: Stack(
                        fit: StackFit.passthrough,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 25,
                                  child: Text(
                                    globalIndex.toString(),
                                    style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    app.iconUrl,
                                    width: 60,
                                    height: 60,
                                     errorBuilder: (context, error, stackTrace) => Container(
                                       width: 60,
                                       height: 60,
                                       decoration: BoxDecoration(
                                         gradient: const LinearGradient(
                                           colors: [Color(0xFF1F1C2C), Color(0xFF928DAB)],
                                         ),
                                         borderRadius: BorderRadius.circular(12),
                                       ),
                                       child: Center(
                                         child: Text(
                                           app.name.isNotEmpty ? app.name[0].toUpperCase() : '🎮',
                                           style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                                         ),
                                       ),
                                     ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        app.name,
                                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${app.size.replaceAll(RegExp(r'\s*MB\s*|\s*م\.ب\s*', caseSensitive: false), '').trim()} MB • ${app.downloadsCount} تنزيل',
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => AppDetailsScreen(app: app, tag: 'top_grid_${app.id}')));
                                },
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }


Widget _buildLatestProductsDrawer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('أحدث المنتجات', showArrow: true, onTap: () {}),
        const SizedBox(height: 15),
        SizedBox(
          height: 160,
          child: _isLoadingLatest
              ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _supabaseLatest.length,
                  itemBuilder: (context, index) {
                    final app = _supabaseLatest[index];
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(left: 15),
                      child: Stack(
  fit: StackFit.passthrough,
  children: [
    Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(18),
                                  image: DecorationImage(
                                    image: NetworkImage(app.iconUrl),
                                    fit: BoxFit.cover,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 5,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              app.name,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              app.developerName,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
    if (app.status == 'coming_soon' || app.status == 'locked')
      Positioned(
        top: 6,
        right: 6,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 3,
              ),
            ],
          ),
          child: const Text(
            'قريباً',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
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
                              builder: (context) => AppDetailsScreen(app: app, tag: 'latest_${app.id}'),
                            ),
                          );
                        },
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    ),
  ],
),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          bool isSelected = _categories[index] == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 15),
            child: Stack(
  fit: StackFit.passthrough,
  children: [
    Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.teal.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? Colors.tealAccent : Colors.grey[800]!,
                  ),
                ),
                child: Text(
                  _categories[index],
                  style: TextStyle(
                    color: isSelected ? Colors.tealAccent : Colors.grey,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
    Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
                setState(() {
                  _selectedCategory = _categories[index];
                });
              },
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    ),
  ],
),
          );
        },
      ),
    );
  }

  Widget _buildBanners() {
    if (_isLoadingBanners) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }
    
    final currentBanners = _selectedIndex == 0 ? _allBanners :
                           _selectedIndex == 2 ? _gameBanners : _appBanners;
    if (currentBanners.isEmpty) return const SizedBox();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 200,
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              if (notification is UserScrollNotification) {
                _resetBannerTimer();
              }
              return false;
            },
            child: PageView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: currentBanners.length,
              controller: _bannerController,
              onPageChanged: (index) {
                setState(() {
                  _currentBannerPage = index % currentBanners.length;
                });
              },
              itemBuilder: (context, index) {
                final app = currentBanners[index];
                String tag = 'banner_${_selectedIndex}_${app.id}';
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(15),
                    image: DecorationImage(
                      image: appImageProvider(app.coverUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Stack(
                      fit: StackFit.passthrough,
                      children: [
                        Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.9),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 15,
                              left: 15,
                              right: 15,
                              child: Row(
                                children: [
                                  Hero(
                                    tag: tag,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: buildAppImage(
                                        app.iconUrl,
                                        width: 45,
                                        height: 45,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          width: 45,
                                          height: 45,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)]),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Center(
                                            child: Text(
                                              app.name.isNotEmpty ? app.name[0].toUpperCase() : '🎮',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          app.name,
                                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          app.developerName,
                                          style: TextStyle(color: Colors.grey[300], fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: app.status == 'coming_soon' ? const Color(0xFFF59E0B) : Colors.teal,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: app.status == 'coming_soon'
                                        ? const Text('قريباً', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
                                        : FutureBuilder<bool>(
                                            future: kIsWeb ? Future.value(false) : DeviceApps.isAppInstalled(app.packageName),
                                            builder: (context, snapshot) {
                                              return Text((snapshot.data ?? false) ? 'فتح' : 'تثبيت', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold));
                                            }
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (app.status == 'coming_soon') ...[
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'قريباً',
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.tealAccent.withOpacity(0.5)),
                                    ),
                                    child: Text(
                                      app.appType == 'game' || app.category.contains('لعب') ? 'لعبة مميزة' : 'تطبيق مميز',
                                      style: const TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Positioned.fill(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AppDetailsScreen(app: app, tag: tag),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (currentBanners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(currentBanners.length, (dotIndex) {
              bool isActive = dotIndex == _currentBannerPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 18 : 6,
                height: 5,
                decoration: BoxDecoration(
                  color: isActive ? Colors.tealAccent : Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title, {bool showArrow = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Stack(
  fit: StackFit.passthrough,
  children: [
    Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (showArrow) const Icon(Icons.arrow_forward_ios, color: Colors.tealAccent, size: 16)
              else const Icon(Icons.arrow_back, color: Colors.grey, size: 20), 
            ],
          ),
        ),
    Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
  ],
),
    );
  }
}

class CategorySection extends StatefulWidget {
  final CategoryConfig config;
  const CategorySection({super.key, required this.config});

  @override
  State<CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<CategorySection> with AutomaticKeepAliveClientMixin {
  List<AppModel> _apps = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchCategoryApps();
  }

  Future<void> _fetchCategoryApps() async {
    try {
      final apps = await ApiService.fetchPaginatedApps(widget.config.query, 0);
      if (mounted) {
        setState(() {
          _apps = apps;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_isLoading) {
      return SizedBox(
        height: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: Container(width: 150, height: 25, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(5))),
            ),
            const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.teal))),
          ],
        ),
      );
    }

    if (_hasError || _apps.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.config.title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Icon(Icons.arrow_back, color: Colors.grey, size: 20), 
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: _apps.length,
            itemBuilder: (context, index) {
              final app = _apps[index];
              String tag = '${widget.config.title}_${app.id}';
              String cleanSize = app.size.replaceAll(RegExp(r'\s*MB\s*|\s*م\.ب\s*', caseSensitive: false), '').trim();
              
              return Material(
                color: Colors.transparent,
                child: Stack(
  fit: StackFit.passthrough,
  children: [
    Container(
                    width: 110,
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Hero(
                          tag: tag,
                          child: Container(
                            height: 95,
                            width: 95,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(20),
                              image: DecorationImage(
                                image: NetworkImage(app.iconUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          app.name,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(app.rating, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            const Icon(Icons.star, color: Colors.grey, size: 10),
                            if (cleanSize.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                '$cleanSize MB', 
                                style: const TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ],
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
                        builder: (context) => AppDetailsScreen(app: app, tag: tag),
                      ),
                    );
                  },
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    ),
  ],
),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class DiscoverMoreScreen extends StatefulWidget {
  final List<AppModel> initialApps;
  final String query;

  const DiscoverMoreScreen({super.key, required this.initialApps, required this.query});

  @override
  State<DiscoverMoreScreen> createState() => _DiscoverMoreScreenState();
}

class _DiscoverMoreScreenState extends State<DiscoverMoreScreen> {
  final ScrollController _scrollController = ScrollController();
  late List<AppModel> _apps;
  bool _isLoading = false;
  int _offset = 0; 
  bool _hasInitialData = false;

  @override
  void initState() {
    super.initState();
    _apps = List.from(widget.initialApps);
    if (_apps.isNotEmpty) {
      _offset = _apps.length;
      _hasInitialData = true;
    } else {
      _fetchMore();
    }
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoading) {
      _fetchMore();
    }
  }

  Future<void> _fetchMore() async {
    setState(() => _isLoading = true);
    final moreApps = await ApiService.fetchPaginatedApps(widget.query, _offset);
    if (mounted) {
      setState(() {
        if (moreApps.isNotEmpty) {
          _offset += 20;
          _apps.addAll(moreApps);
        }
        _isLoading = false;
        _hasInitialData = true;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('اكتشاف المزيد', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: !_hasInitialData
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
          : Column(
              children: [
                Expanded(
                  child: GridView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(15),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: _apps.length,
                    itemBuilder: (context, index) {
                      final app = _apps[index];
                      String tag = 'discover_${app.id}_$index';
                      return _buildGridItem(app, tag, context);
                    },
                  ),
                ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
                  ),
              ],
            ),
    );
  }

  Widget _buildGridItem(AppModel app, String tag, BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
  fit: StackFit.passthrough,
  children: [
    Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: tag,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(
                  app.iconUrl,
                  height: 90,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 90,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF1F1C2C), Color(0xFF928DAB)]),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Center(
                      child: Text(
                        app.name.isNotEmpty ? app.name[0].toUpperCase() : '🎮',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              app.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Row(
              children: [
                Text(app.rating, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                const Icon(Icons.star, color: Colors.grey, size: 10),
              ],
            ),
          ],
        ),
    if (app.status == 'coming_soon' || app.status == 'locked')
      Positioned(
        top: 6,
        right: 6,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 3,
              ),
            ],
          ),
          child: const Text(
            'قريباً',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
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
              builder: (context) => AppDetailsScreen(app: app, tag: tag),
            ),
          );
        },
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    ),
  ],
),
    );
  }
}

class AppSearchDelegate extends SearchDelegate<AppModel?> {
  @override
  String get searchFieldLabel => 'البحث عن التطبيقات والألعاب...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        )
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().isEmpty) return const SizedBox();
    
    return FutureBuilder<List<AppModel>>(
      future: ApiService.searchApps(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.teal));
        }
        if (snapshot.hasError) {
          return Center(child: Text('خطأ في البحث', style: const TextStyle(color: Colors.red)));
        }
        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          return const Center(child: Text('لم يتم العثور على نتائج.', style: TextStyle(color: Colors.grey)));
        }
        
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final app = results[index];
            String tag = 'search_${app.id}';
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Hero(
                tag: tag,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(app.iconUrl, width: 50, height: 50, fit: BoxFit.cover),
                ),
              ),
              title: Text(app.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(app.developerName, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              trailing: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AppDetailsScreen(app: app, tag: tag),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.withOpacity(0.2),
                  foregroundColor: Colors.tealAccent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: FutureBuilder<bool>(
                  future: kIsWeb ? Future.value(false) : DeviceApps.isAppInstalled(app.packageName),
                  builder: (context, snapshot) {
                    return Text((snapshot.data ?? false) ? 'فتح' : 'تثبيت');
                  }
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AppDetailsScreen(app: app, tag: tag),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const Center(
      child: Text('ابحث في ملايين التطبيقات...', style: TextStyle(color: Colors.grey)),
    );
  }
  
  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.grey),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white, fontSize: 18),
      ),
      scaffoldBackgroundColor: Colors.black,
    );
  }
}
