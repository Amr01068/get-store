import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_model.dart';
import '../models/nomination_model.dart';

enum VoteActionType { voted, unvoted, switched }

class VoteResult {
  final bool success;
  final VoteActionType actionType;
  final String? previousCandidateId;
  final String? activeCandidateId;
  final String message;

  VoteResult({
    required this.success,
    this.actionType = VoteActionType.voted,
    this.previousCandidateId,
    this.activeCandidateId,
    this.message = '',
  });
}

class ApiService {
  // دالة البحث الحقيقي من الـ Supabase فقط (باستثناء الترشيحات)
  static Future<List<AppModel>> searchApps(String query) async {
    try {
      List<AppModel> results = [];
      
      final supaRes = await Supabase.instance.client
          .from('apps')
          .select('*, total_rating, rating_count')
          .or('status.eq.approved,status.eq.coming_soon')
          .neq('category', 'nomination')
          .ilike('title', '%$query%')
          .order('created_at', ascending: false)
          .limit(20);
          
      if (supaRes != null) {
        final List supaApps = supaRes as List;
        results.addAll(supaApps.map((e) => AppModel.fromSupabaseJson(e)));
      }

      return results;
    } catch (e) {
      print('Supabase search error: $e');
      return [];
    }
  }

  // دالة لجلب التطبيقات والألعاب المعتمدة من Supabase فقط
  static Future<List<AppModel>> fetchPaginatedApps(String query, int offset) async {
    try {
      List<AppModel> results = [];
      String q = query.toLowerCase().trim();
      bool filterGames = q.contains('game') || q.contains('العاب') || q.contains('ألعاب') || q.contains('لعب');
      bool filterApps = q.contains('app') || q.contains('تطبيق') || q.contains('برامج');

      final supaRes = await Supabase.instance.client
          .from('apps')
          .select('*, total_rating, rating_count')
          .or('status.eq.approved,status.eq.coming_soon')
          .neq('category', 'nomination')
          .order('created_at', ascending: false);
      
      if (supaRes != null) {
        final List supaApps = supaRes as List;
        for (var json in supaApps) {
          final app = AppModel.fromSupabaseJson(json);
          bool isGame = app.appType == 'game' ||
                        app.category.contains('لعب') || 
                        app.category.toLowerCase().contains('game') || 
                        app.category.contains('ألعاب') || 
                        app.category.contains('العاب');
          
          if (filterGames && !isGame) continue;
          if (filterApps && isGame) continue;

          // مطابقة بالكلمات إذا كان الاستعلام مخصص
          if (q.isNotEmpty && !filterGames && !filterApps) {
            final words = q.split(' ');
            bool matches = words.any((w) => 
              w.length > 2 && (
                app.name.toLowerCase().contains(w) ||
                app.category.toLowerCase().contains(w) ||
                app.description.toLowerCase().contains(w)
              )
            );
            if (!matches) continue;
          }

          results.add(app);
        }
      }

      return results;
    } catch (e) {
      print('Supabase fetch error: $e');
      return [];
    }
  }

  // دالة لجلب أحدث التطبيقات والألعاب المعتمدة من Supabase
  static Future<List<AppModel>> fetchSupabaseLatest() async {
    try {
      final res = await Supabase.instance.client
          .from('apps')
          .select('*, total_rating, rating_count')
          .or('status.eq.approved,status.eq.coming_soon')
          .neq('category', 'nomination')
          .order('created_at', ascending: false)
          .limit(10);
      
      if (res != null) {
        return (res as List).map((e) => AppModel.fromSupabaseJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Supabase latest error: $e');
      return [];
    }
  }

  // دالة لجلب التطبيقات الأكثر تحميلاً من Supabase
  static Future<List<AppModel>> fetchTopDownloadedApps() async {
    try {
      final res = await Supabase.instance.client
          .from('apps')
          .select('*, total_rating, rating_count')
          .eq('status', 'approved')
          .neq('category', 'nomination')
          .order('downloads', ascending: false)
          .limit(9);
          
      if (res != null) {
        return (res as List).map((e) => AppModel.fromSupabaseJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Fetch top downloaded apps error: $e');
      return [];
    }
  }

  // تفاصيل التطبيق تأتي كاملة من Supabase بدون أي API خارجي
  static Future<AppModel> fetchAppFullDetails(AppModel app) async {
    return app;
  }

  // زيادة عدد التحميلات في Supabase
  static Future<void> incrementAppDownloads(String appId) async {
    try {
      final intId = int.tryParse(appId);
      if (intId != null) {
        await Supabase.instance.client.rpc('increment_app_downloads', params: {'p_app_id': intId});
      }
    } catch (e) {
      print('Increment downloads error: $e');
    }
  }

  // جلب تطبيقات المطور من Supabase فقط
  static Future<List<AppModel>> fetchDeveloperApps(AppModel devApp) async {
    try {
      final res = await Supabase.instance.client
          .from('apps')
          .select('*, total_rating, rating_count')
          .or('status.eq.approved,status.eq.coming_soon')
          .neq('category', 'nomination')
          .order('created_at', ascending: false);
          
      if (res != null) {
        var all = (res as List).map((e) => AppModel.fromSupabaseJson(e)).toList();
        return all.where((a) => a.developerName == devApp.developerName).toList();
      }
      return [];
    } catch (e) {
      print('Fetch developer apps error: $e');
      return [];
    }
  }

  // إرسال تقييم التطبيق إلى Supabase
  static Future<Map<String, dynamic>> submitAppRating(String appId, double newRating, double oldRating) async {
    try {
      final response = await Supabase.instance.client
          .from('apps')
          .select('total_rating, rating_count')
          .eq('id', appId)
          .single();
          
      num currentTotal = response['total_rating'] ?? 0;
      int currentCount = response['rating_count'] ?? 0;
      
      if (oldRating > 0 && currentCount > 0) {
        currentTotal = (currentTotal - oldRating) + newRating;
        if (currentTotal < 0) currentTotal = 0;
      } else {
        currentTotal = currentTotal + newRating;
        currentCount = currentCount + 1;
      }

      double finalAvg = currentCount > 0 ? (currentTotal / currentCount) : 0.0;
      
      await Supabase.instance.client
          .from('apps')
          .update({
            'total_rating': currentTotal,
            'rating_count': currentCount,
          })
          .eq('id', appId);
          
      return {
        'success': true,
        'rating': finalAvg.toStringAsFixed(1),
        'reviewsCount': '$currentCount مراجعة',
      };
    } catch (e) {
      print('خطأ في إرسال التقييم: $e');
      return {'success': false};
    }
  }

  // ==========================================
  // نظام الترشيحات واستطلاع الرأي (Nominations)
  // ==========================================

  // جلب الترشيحات النشطة من Supabase
  static Future<List<NominationModel>> fetchActiveNominations() async {
    try {
      final res = await Supabase.instance.client
          .from('apps')
          .select('*')
          .eq('category', 'nomination')
          .eq('status', 'approved')
          .order('created_at', ascending: false);

      if (res != null) {
        final List list = res as List;
        return list.map((e) => NominationModel.fromSupabaseJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Fetch nominations error: $e');
      return [];
    }
  }

  // الحصول على معرف فريد ودائم للجهاز لمنع تكرار التصويت
  static Future<String> getDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('app_device_uuid');
      if (deviceId == null || deviceId.isEmpty) {
        final rand = Random();
        final p1 = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
        final p2 = rand.nextInt(0xFFFFFF).toRadixString(16);
        final p3 = rand.nextInt(0xFFFFFF).toRadixString(16);
        deviceId = 'dev_${p1}_${p2}_$p3';
        await prefs.setString('app_device_uuid', deviceId);
      }
      return deviceId;
    } catch (e) {
      return 'dev_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // تسجيل تصويت أو تحويله لمرشح آخر أو إلغائه بنقرة ثانية (صوت واحد مرن لكل جهاز)
  static Future<VoteResult> toggleOrSwitchVote(
    String nominationId, 
    String candidateId, 
    [String? deviceId]
  ) async {
    try {
      deviceId ??= await getDeviceId();

      final res = await Supabase.instance.client
          .from('apps')
          .select('package_name')
          .eq('id', nominationId)
          .single();

      final pkgStr = res['package_name']?.toString() ?? '{}';
      final meta = jsonDecode(pkgStr) as Map<String, dynamic>;

      // قراءة خريطة المصوتين لربط كل جهاز بالمرشح الذي اختاره بدقة
      Map<String, dynamic> voters = {};
      if (meta['voters'] is Map) {
        voters = Map<String, dynamic>.from(meta['voters'] as Map);
      } else if (meta['voters'] is List) {
        for (var v in (meta['voters'] as List)) {
          voters[v.toString()] = '';
        }
      }

      final candidates = (meta['candidates'] as List?) ?? [];
      final prevCandId = voters[deviceId]?.toString();

      VoteActionType actionType;
      String? activeCandidateId;

      if (prevCandId == candidateId) {
        // 1. المستخدم ضغط على نفس الخيار الذي صوّت له -> يتم إلغاء التصويت بالكامل
        actionType = VoteActionType.unvoted;
        activeCandidateId = null;
        voters.remove(deviceId);

        for (var c in candidates) {
          if (c['id']?.toString() == candidateId) {
            int currentVotes = (c['votes'] is num) 
                ? (c['votes'] as num).toInt() 
                : int.tryParse(c['votes']?.toString() ?? '0') ?? 0;
            c['votes'] = max(0, currentVotes - 1);
            break;
          }
        }
      } else if (prevCandId != null && prevCandId.isNotEmpty) {
        // 2. المستخدم كان قد صوت لخيار سابق وضغط على خيار آخر -> يتم تحويل صوته
        actionType = VoteActionType.switched;
        activeCandidateId = candidateId;
        voters[deviceId] = candidateId;

        for (var c in candidates) {
          final cId = c['id']?.toString();
          int currentVotes = (c['votes'] is num) 
              ? (c['votes'] as num).toInt() 
              : int.tryParse(c['votes']?.toString() ?? '0') ?? 0;

          if (cId == prevCandId) {
            c['votes'] = max(0, currentVotes - 1);
          } else if (cId == candidateId) {
            c['votes'] = currentVotes + 1;
          }
        }
      } else {
        // 3. تصويت جديد لأول مرة
        actionType = VoteActionType.voted;
        activeCandidateId = candidateId;
        voters[deviceId] = candidateId;

        for (var c in candidates) {
          if (c['id']?.toString() == candidateId) {
            int currentVotes = (c['votes'] is num) 
                ? (c['votes'] as num).toInt() 
                : int.tryParse(c['votes']?.toString() ?? '0') ?? 0;
            c['votes'] = currentVotes + 1;
            break;
          }
        }
      }

      // إعادة حساب إجمالي الأصوات وتحديثه
      int total = 0;
      for (var c in candidates) {
        int v = (c['votes'] is num) ? (c['votes'] as num).toInt() : int.tryParse(c['votes']?.toString() ?? '0') ?? 0;
        total += v;
      }
      meta['totalVotes'] = total;
      meta['voters'] = voters;

      await Supabase.instance.client
          .from('apps')
          .update({
            'package_name': jsonEncode(meta),
          })
          .eq('id', nominationId);

      return VoteResult(
        success: true,
        actionType: actionType,
        previousCandidateId: prevCandId,
        activeCandidateId: activeCandidateId,
        message: actionType == VoteActionType.unvoted
            ? 'تم إلغاء التصويت بنجاح'
            : (actionType == VoteActionType.switched
                ? 'تم تحويل صوتك بنجاح'
                : 'تم تسجيل التصويت بنجاح'),
      );
    } catch (e) {
      print('Vote toggle or switch error: $e');
      return VoteResult(success: false, message: 'خطأ أثناء تسجيل العملية: $e');
    }
  }

  static Future<VoteResult> voteForNominationCandidate(String nominationId, String candidateId, [String? deviceId]) async {
    return toggleOrSwitchVote(nominationId, candidateId, deviceId);
  }

  // جلب التطبيقات والألعاب الحقيقية التي نشرها المطور (سواء قريباً أو منشور) والتي تمتلك صورة غلاف مميزة
  static Future<List<AppModel>> fetchTopFeaturedBanners({String type = 'all'}) async {
    try {
      final supaRes = await Supabase.instance.client
          .from('apps')
          .select('*, total_rating, rating_count')
          .or('status.eq.approved,status.eq.coming_soon')
          .neq('category', 'nomination')
          .order('created_at', ascending: false);

      List<AppModel> results = [];
      if (supaRes != null) {
        final List list = supaRes as List;
        for (var json in list) {
          final app = AppModel.fromSupabaseJson(json);
          
          // شرط أساسي: التطبيق يجب أن يمتلك صورة غلاف مميزة حقيقية (Base64 أو رابط صورة كامل)
          final cover = app.coverUrl.trim();
          bool hasValidCover = cover.isNotEmpty && 
                               !cover.contains('picsum.photos') && 
                               !cover.contains('placeholder');
          if (!hasValidCover) continue;

          bool isGame = app.appType == 'game' ||
                        app.category.contains('لعب') || 
                        app.category.toLowerCase().contains('game') || 
                        app.category.contains('ألعاب') || 
                        app.category.contains('العاب');
          
          if (type == 'games' && !isGame) continue;
          if (type == 'apps' && isGame) continue;
          results.add(app);
        }
      }

      // ترتيب حسب الأحدث والأعلى تفاعلاً
      results.sort((a, b) {
        if (b.rawRating != a.rawRating) {
          return b.rawRating.compareTo(a.rawRating);
        }
        return b.rawDownloads.compareTo(a.rawDownloads);
      });

      // أقصى عدد هو أفضل 5 تطبيقات/ألعاب حقيقية للمطور
      return results.take(5).toList();
    } catch (e) {
      print('Fetch featured banners error: $e');
      return [];
    }
  }
}
