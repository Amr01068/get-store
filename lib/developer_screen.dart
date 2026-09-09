import 'package:flutter/material.dart';
import 'models/app_model.dart';
import 'services/api_service.dart';
import 'app_details_screen.dart';

class DeveloperScreen extends StatefulWidget {
  final AppModel app;

  const DeveloperScreen({super.key, required this.app});

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> {
  List<AppModel> _devApps = [];
  bool _isLoading = true;
  String _totalDownloads = '0';
  String _totalApps = '0';
  String _avgRating = '0.0';
  AppModel? _featuredApp;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final apps = await ApiService.fetchDeveloperApps(widget.app);
    if (!mounted) return;
    
    int totalDl = 0;
    double totalRating = 0.0;
    int validRatings = 0;
    
    for (var a in apps) {
      totalDl += a.rawDownloads;
      
      if (a.rawRating > 0) {
        totalRating += a.rawRating;
        validRatings++;
      }
    }

    String formattedDl = _formatLargeNumber(totalDl);
    String avgR = validRatings > 0 ? (totalRating / validRatings).toStringAsFixed(1) : '0.0';

    AppModel? featured;
    if (apps.isNotEmpty && widget.app.developerFeaturedApp.isNotEmpty) {
      try {
        featured = apps.firstWhere((a) => a.id == widget.app.developerFeaturedApp);
      } catch (_) {
        featured = null;
      }
    }

    setState(() {
      _devApps = apps;
      _totalApps = apps.length.toString();
      _totalDownloads = formattedDl == '0' ? '0' : '+$formattedDl'; 
      _avgRating = avgR;
      _featuredApp = featured;
      _isLoading = false;
    });
  }

  String _formatLargeNumber(int num) {
    if (num == 0) return '0';
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // غلاف المطور (Cover)
          SliverAppBar(
            expandedHeight: 320.0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  buildAppImage(
                    widget.app.developerCover,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[900]),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.2), Colors.black],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[800],
                            border: Border.all(color: Colors.tealAccent, width: 2),
                            image: DecorationImage(
                              image: appImageProvider(widget.app.developerLogo),
                              fit: BoxFit.cover,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.tealAccent.withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.app.developerName,
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                        ),

                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  
                  // إحصائيات المطور ومتابعة
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDevStat('التطبيقات', _isLoading ? '...' : _totalApps),
                        _buildDivider(),
                        _buildDevStat('التحميلات', _isLoading ? '...' : _totalDownloads),
                        _buildDivider(),
                        _buildDevStat('التقييم', _isLoading ? '...' : _avgRating),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 25),
                  
                  // نبذة عن المطور (Bio)
                  const Text(
                    'نبذة عن المطور',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.app.developerBio,
                    style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 35),

                  // التطبيق المميز للمطور (Featured App)
                  if (!_isLoading && _featuredApp != null) ...[
                    const Text(
                      'التطبيق المميز للمطور',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    Stack(
  fit: StackFit.passthrough,
  children: [
    Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.teal.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    image: DecorationImage(
                                      image: NetworkImage(_featuredApp!.iconUrl),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_featuredApp!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(_featuredApp!.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Text(_featuredApp!.rating, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                          const Icon(Icons.star, color: Colors.orange, size: 14),
                                          const SizedBox(width: 10),
                                          Text('${_featuredApp!.downloadsCount} تنزيل', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            SizedBox(
                              width: double.infinity,
                              height: 45,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => AppDetailsScreen(app: _featuredApp!, tag: 'dev_featured_btn_${_featuredApp!.id}')));
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                ),
                                child: const Text('تثبيت الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
                        Navigator.push(context, MaterialPageRoute(builder: (_) => AppDetailsScreen(app: _featuredApp!, tag: 'dev_featured_${_featuredApp!.id}')));
                      },
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    ),
  ],
),
                    const SizedBox(height: 35),
                  ],
                  
                  if (_isLoading) const Center(child: CircularProgressIndicator(color: Colors.tealAccent)),

                  if (!_isLoading && _devApps.isNotEmpty) ...[
                    Text(
                      'تطبيقات بواسطة ${widget.app.developerName}',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                  ],
                ],
              ),
            ),
          ),
          
          // شبكة تطبيقات المطور
          if (!_isLoading && _devApps.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 130, 
                  childAspectRatio: 0.72, 
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 25,
                ),
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    return _buildAppGridItem(_devApps[index], context);
                  },
                  childCount: _devApps.length, 
                ),
              ),
            ),
            
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildDevStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey[700],
    );
  }

  Widget _buildAppGridItem(AppModel devApp, BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
  fit: StackFit.passthrough,
  children: [
    Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(18),
                    image: DecorationImage(
                      image: NetworkImage(devApp.iconUrl),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              devApp.name,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(devApp.rating, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(width: 2),
                const Icon(Icons.star, color: Colors.orange, size: 12),
              ],
            ),
          ],
        ),
    Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => AppDetailsScreen(app: devApp, tag: 'dev_grid_${devApp.id}')));
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
