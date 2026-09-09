import 'dart:convert';
import 'package:flutter/material.dart';

class AppModel {
  final String id;
  final String packageName;
  final String name;
  final String developerName;
  final String developerLogo;
  final String description;
  final String iconUrl;
  final String coverUrl;
  final List<String> screenshots;
  final String apkUrl;
  final String rating;
  final String reviewsCount;
  final String downloadsCount;
  final int rawDownloads;
  final double rawRating;
  final String size;
  final String category;
  final String version;
  final String whatsNew;
  final String releaseDate;
  final String updateDate;
  final String developerCover;
  final String developerBio;
  final String developerEmail;
  final String developerFeaturedApp;
  final bool containsAds;
  final bool inAppPurchases;
  final String status;
  final String? youtubeUrl;
  final String contentRating;
  final String appType;

  AppModel({
    required this.id,
    required this.packageName,
    required this.name,
    required this.developerName,
    required this.developerLogo,
    required this.description,
    required this.iconUrl,
    required this.coverUrl,
    required this.screenshots,
    required this.apkUrl,
    required this.rating,
    required this.reviewsCount,
    required this.downloadsCount,
    this.rawDownloads = 0,
    this.rawRating = 0.0,
    required this.size,
    required this.category,
    required this.version,
    required this.whatsNew,
    required this.releaseDate,
    required this.updateDate,
    required this.developerCover,
    required this.developerBio,
    required this.developerEmail,
    required this.developerFeaturedApp,
    required this.containsAds,
    required this.inAppPurchases,
    required this.status,
    this.youtubeUrl,
    this.contentRating = '3+',
    this.appType = 'app',
  });

  AppModel copyWith({
    String? description,
    List<String>? screenshots,
    String? whatsNew,
    String? developerName,
    String? developerLogo,
    String? coverUrl,
    String? rating,
    String? reviewsCount,
    bool? containsAds,
    bool? inAppPurchases,
    String? status,
    String? youtubeUrl,
    String? iconUrl,
    String? apkUrl,
    String? size,
    String? version,
    String? appType,
  }) {
    return AppModel(
      id: id,
      packageName: packageName,
      name: name,
      developerName: developerName ?? this.developerName,
      developerLogo: developerLogo ?? this.developerLogo,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      screenshots: screenshots ?? this.screenshots,
      apkUrl: apkUrl ?? this.apkUrl,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      downloadsCount: downloadsCount ?? this.downloadsCount,
      rawDownloads: rawDownloads ?? this.rawDownloads,
      rawRating: rawRating ?? this.rawRating,
      size: size ?? this.size,
      category: category ?? this.category,
      version: version ?? this.version,
      whatsNew: whatsNew ?? this.whatsNew,
      releaseDate: releaseDate ?? this.releaseDate,
      updateDate: updateDate,
      developerCover: developerCover,
      developerBio: developerBio,
      developerEmail: developerEmail,
      developerFeaturedApp: developerFeaturedApp,
      containsAds: containsAds ?? this.containsAds,
      inAppPurchases: inAppPurchases ?? this.inAppPurchases,
      status: status ?? this.status,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      appType: appType ?? this.appType,
    );
  }

  static String _parseString(dynamic value, String fallback) {
    if (value == null) return fallback;
    if (value is String && value.trim().isEmpty) return fallback;
    return value.toString();
  }

  static String _proxify(String url) {
    if (url.isEmpty) return 'https://picsum.photos/200?icon';
    return url;
  }

  static String _formatDownloads(int count) {
    if (count == 0) return '0';
    if (count >= 1000000000) {
      return '+${(count / 1000000000).toStringAsFixed(1).replaceAll('.0', '')} مليار';
    } else if (count >= 1000000) {
      return '+${(count / 1000000).toStringAsFixed(1).replaceAll('.0', '')} مليون';
    } else if (count >= 1000) {
      int thousands = (count / 1000).floor();
      if (thousands >= 3 && thousands <= 10) return '+$thousands آلاف';
      return '+$thousands ألف';
    }
    return '+$count';
  }

  static String _formatSize(int bytes) {
    return (bytes / (1024 * 1024)).toStringAsFixed(1);
  }

  static String _formatDate(dynamic dateVal) {
    if (dateVal == null) return 'غير متوفر';
    String str = dateVal.toString().trim();
    if (str.isEmpty) return 'غير متوفر';
    if (str.contains('T')) {
      str = str.split('T').first;
    }
    return str;
  }

  factory AppModel.fromFDroidJson(Map<String, dynamic> json, String cat) {
    String pkg = _parseString(json['packageName'] ?? json['package_name'] ?? json['id'], '');
    String name = _parseString(json['name'] ?? json['title'] ?? json['app_name'], 'تطبيق مفتوح المصدر');
    String desc = _parseString(json['summary'] ?? json['description'], 'تطبيق أندرويد مفتوح المصدر وآمن من مجتمع F-Droid.');
    String iconName = _parseString(json['icon'] ?? json['icon_url'], '');
    String iconUrl = (iconName.isNotEmpty && iconName.startsWith('http'))
        ? iconName
        : (pkg.isNotEmpty ? 'https://f-droid.org/repo/icons-640/$pkg.png' : 'https://picsum.photos/200?icon');
    
    String apk = _parseString(json['apkUrl'] ?? json['apk_url'], '');
    if (apk.isEmpty && pkg.isNotEmpty) {
      apk = 'https://f-droid.org/repo/${pkg}_latest.apk';
    }

    return AppModel(
      id: pkg.isNotEmpty ? pkg : DateTime.now().millisecondsSinceEpoch.toString(),
      packageName: pkg,
      name: name,
      developerName: _parseString(json['authorName'] ?? json['developer'], 'F-Droid Community'),
      developerLogo: 'https://f-droid.org/assets/fdroid-logo.png',
      description: desc,
      iconUrl: iconUrl,
      coverUrl: iconUrl,
      screenshots: [iconUrl],
      apkUrl: apk,
      rating: '4.8',
      reviewsCount: '1,500+ مراجعة',
      downloadsCount: '50,000+',
      rawDownloads: 50000,
      rawRating: 4.8,
      size: _parseString(json['size'], '18 MB'),
      category: cat.isEmpty ? 'مفتوح المصدر' : cat,
      version: _parseString(json['versionName'] ?? json['version'], '1.0.0'),
      whatsNew: 'نسخة آمنة ومفتوحة المصدر خالية من الإعلانات والتتبع.',
      releaseDate: _formatDate(json['added']),
      updateDate: _formatDate(json['lastUpdated'] ?? json['added']),
      developerCover: 'https://picsum.photos/1000/600',
      developerBio: 'مبتكر تطبيقات أندرويد مفتوحة المصدر عالية الأداء والخصوصية.',
      developerEmail: '',
      developerFeaturedApp: '',
      containsAds: false,
      inAppPurchases: false,
      status: 'approved',
      contentRating: '3+',
    );
  }

  factory AppModel.fromAptoideJson(Map<String, dynamic> json, String cat) {
    String desc = _parseString(json['description'], 'جاري جلب بيانات التطبيق التفصيلية...');
    String icon = _parseString(json['icon'], 'https://picsum.photos/200?icon');
    String graphic = _parseString(json['graphic'], icon);
    
    return AppModel(
      id: _parseString(json['id'], ''),
      packageName: _parseString(json['package'], ''),
      name: _parseString(json['name'], 'تطبيق غير معروف'),
      developerName: json['developer'] != null ? _parseString(json['developer']['name'], 'مطور غير معروف') : 'مطور غير معروف',
      developerLogo: _proxify(json['store'] != null ? _parseString(json['store']['avatar'], 'https://picsum.photos/200?dev') : 'https://picsum.photos/200?dev'),
      description: desc,
      iconUrl: _proxify(icon),
      coverUrl: _proxify(graphic),
      screenshots: [_proxify(graphic), _proxify(icon)],
      apkUrl: json['file'] != null ? _parseString(json['file']['path'], '') : '',
      rating: json['stats'] != null && json['stats']['rating'] != null ? _parseString(json['stats']['rating']['avg'], '4.0') : '4.0',
      reviewsCount: json['stats'] != null && json['stats']['rating'] != null ? '${json['stats']['rating']['total'] ?? 0} مراجعة' : '0 مراجعة',
      downloadsCount: json['stats'] != null ? _formatDownloads(json['stats']['downloads'] ?? 0) : '0',
      rawDownloads: json['stats'] != null ? (json['stats']['downloads'] ?? 0) : 0,
      rawRating: json['stats'] != null && json['stats']['rating'] != null ? double.tryParse(json['stats']['rating']['avg'].toString()) ?? 4.0 : 4.0,
      size: json['file'] != null && json['file']['filesize'] != null ? _formatSize(json['file']['filesize']) : 'غير متوفر',
      category: cat,
      version: json['file'] != null ? _parseString(json['file']['vername'], '1.0') : '1.0',
      whatsNew: 'لا توجد معلومات عن التحديثات الجديدة.',
      releaseDate: _parseString(json['added'], 'غير متوفر').split(' ').first,
      updateDate: _parseString(json['updated'] ?? json['modified'], 'غير متوفر').split(' ').first,
      developerCover: 'https://picsum.photos/1000/600',
      developerBio: 'مطور تطبيقات وألعاب على متجر GET STORE.',
      developerEmail: '',
      developerFeaturedApp: '',
      containsAds: json['stats'] != null && json['stats']['pr'] != null && json['stats']['pr']['has_ads'] == true,
      inAppPurchases: json['stats'] != null && json['stats']['pr'] != null && json['stats']['pr']['has_iap'] == true,
      status: 'approved',
      youtubeUrl: null,
    );
  }

  factory AppModel.fromSupabaseJson(Map<String, dynamic> json) {
    Map<String, dynamic>? metadata;
    try {
      if (json['package_name'] != null && json['package_name'].toString().startsWith('{')) {
        metadata = jsonDecode(json['package_name']) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error parsing Supabase metadata: $e');
    }

    String devName = 'مطور مجهول';
    String devLogo = 'https://picsum.photos/200?dev';
    String devCover = 'https://picsum.photos/1000/600?cover';
    String devBio = 'مطور تطبيقات وألعاب على منصة GET STORE. يقدم أفضل التطبيقات لخدمة المستخدمين.';
    String devEmail = json['email'] ?? '';
    String devFeaturedApp = '';
    bool hasAds = false;
    bool hasPurchases = false;
    String whatsNew = 'لا توجد معلومات عن التحديثات الجديدة.';
    String? youtubeUrl;
    
    if (metadata != null) {
      if (metadata['developerProfile'] != null) {
        final profile = metadata['developerProfile'];
        devName = profile['name'] ?? devName;
        devLogo = profile['avatar'] ?? devLogo;
        devCover = profile['cover'] ?? devCover;
        devBio = profile['bio'] ?? devBio;
        devFeaturedApp = profile['featuredApp'] ?? '';
      }
      hasAds = metadata['containsAds'] ?? false;
      hasPurchases = metadata['inAppPurchases'] ?? false;
      whatsNew = metadata['whatsNew'] ?? whatsNew;
      youtubeUrl = metadata['youtubeUrl'];
    }

    String appSize = metadata?['appSize'] ?? 'غير متوفر';
    final int ratingCount = json['rating_count'] ?? 0;
    final num totalRating = json['total_rating'] ?? 0;
    final double calculatedRating = ratingCount > 0 ? (totalRating / ratingCount) : 0.0;

    String parsedAppType = (metadata?['appType'] ?? '').toString().trim().toLowerCase();
    if (parsedAppType.isEmpty) {
      final cat = (json['category'] ?? '').toString().toLowerCase();
      if (cat.contains('لعب') || cat.contains('game') || cat.contains('أكشن') || cat.contains('action') ||
          cat.contains('سباق') || cat.contains('racing') || cat.contains('ألغاز') || cat.contains('puzzle') ||
          cat.contains('استراتيجية') || cat.contains('strategy') || cat.contains('رياضة') || cat.contains('sports')) {
        parsedAppType = 'game';
      } else {
        parsedAppType = 'app';
      }
    }

    return AppModel(
      id: json['id']?.toString() ?? '',
      packageName: metadata?['realPackageName'] ?? 'com.supabase.app.${json['id']}',
      name: json['title'] ?? 'تطبيق غير معروف',
      developerName: devName,
      developerLogo: devLogo,
      description: json['description'] ?? 'لا يوجد وصف متاح.',
      iconUrl: json['icon_url'] ?? 'https://picsum.photos/200?icon',
      coverUrl: json['cover_url'] ?? 'https://picsum.photos/500/200?cover',
      screenshots: (json['screenshots_urls'] as List?)?.map((e) => e.toString()).toList() ?? [],
      apkUrl: json['apk_github_url'] ?? '',
      rating: calculatedRating > 0 ? calculatedRating.toStringAsFixed(1) : '0.0',
      reviewsCount: ratingCount > 0 ? '$ratingCount مراجعة' : '0 مراجعة',
      downloadsCount: _formatDownloads(json['downloads'] ?? 0),
      rawDownloads: json['downloads'] ?? 0,
      rawRating: calculatedRating,
      size: appSize,
      category: json['category'] ?? 'تطبيقات',
      version: metadata?['version'] ?? json['version'] ?? '1.0.0',
      whatsNew: whatsNew,
      developerCover: devCover,
      developerBio: devBio,
      developerEmail: devEmail,
      developerFeaturedApp: devFeaturedApp,
      containsAds: hasAds,
      inAppPurchases: hasPurchases,
      releaseDate: _formatDate(json['created_at']),
      updateDate: _formatDate(json['updated_at'] ?? json['created_at']),
      status: metadata?['status'] ?? json['status'] ?? 'approved',
      contentRating: metadata?['contentRating'] ?? json['content_rating'] ?? '3+',
      youtubeUrl: youtubeUrl ?? metadata?['youtubeUrl'],
      appType: parsedAppType,
    );
  }
}

ImageProvider appImageProvider(String? url, {String defaultPlaceholder = 'https://picsum.photos/200'}) {
  if (url == null || url.trim().isEmpty) {
    return NetworkImage(defaultPlaceholder);
  }
  final trimmed = url.trim();
  if (trimmed.startsWith('data:image')) {
    try {
      final commaIndex = trimmed.indexOf(',');
      final rawBase64 = commaIndex != -1 ? trimmed.substring(commaIndex + 1) : trimmed;
      final cleanBase64 = rawBase64.replaceAll('\n', '').replaceAll('\r', '').trim();
      return MemoryImage(base64Decode(cleanBase64));
    } catch (_) {
      return NetworkImage(defaultPlaceholder);
    }
  }
  return NetworkImage(trimmed);
}

Widget buildAppImage(String? url, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  String placeholder = 'https://picsum.photos/200',
}) {
  if (url != null && url.trim().startsWith('data:image')) {
    try {
      final commaIndex = url.indexOf(',');
      final rawBase64 = commaIndex != -1 ? url.substring(commaIndex + 1) : url;
      final cleanBase64 = rawBase64.replaceAll('\n', '').replaceAll('\r', '').trim();
      return Image.memory(
        base64Decode(cleanBase64),
        fit: fit,
        width: width,
        height: height,
        errorBuilder: errorBuilder ?? (context, error, stackTrace) => Container(color: Colors.grey[900]),
      );
    } catch (_) {}
  }
  return Image.network(
    url ?? placeholder,
    fit: fit,
    width: width,
    height: height,
    errorBuilder: errorBuilder ?? (context, error, stackTrace) => Container(color: Colors.grey[900]),
  );
}
