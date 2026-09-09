import 'dart:convert';

class NominationCandidate {
  final String id;
  final String name;
  final String type; // 'app' or 'game'
  final String image;
  final String description;
  final int votes;

  NominationCandidate({
    required this.id,
    required this.name,
    required this.type,
    required this.image,
    required this.description,
    required this.votes,
  });

  factory NominationCandidate.fromJson(Map<String, dynamic> json) {
    return NominationCandidate(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'مرشح غير معروف',
      type: (json['type']?.toString() ?? 'app').toLowerCase(),
      image: json['image']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      votes: (json['votes'] is num) ? (json['votes'] as num).toInt() : int.tryParse(json['votes']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'image': image,
      'description': description,
      'votes': votes,
    };
  }

  NominationCandidate copyWith({int? votes}) {
    return NominationCandidate(
      id: id,
      name: name,
      type: type,
      image: image,
      description: description,
      votes: votes ?? this.votes,
    );
  }
}

class NominationModel {
  final String id;
  final String title;
  final String description;
  final String developerEmail;
  final String developerName;
  final List<NominationCandidate> candidates;
  final Map<String, String> voters;
  final DateTime createdAt;

  NominationModel({
    required this.id,
    required this.title,
    required this.description,
    required this.developerEmail,
    this.developerName = 'kko studio EGYPT',
    required this.candidates,
    this.voters = const {},
    required this.createdAt,
  });

  int get totalVotes => candidates.fold(0, (sum, c) => sum + c.votes);

  bool hasDeviceVoted(String deviceId) => voters.containsKey(deviceId);
  String? getDeviceVotedCandidate(String deviceId) => voters[deviceId];

  factory NominationModel.fromSupabaseJson(Map<String, dynamic> json) {
    List<NominationCandidate> parsedCandidates = [];
    Map<String, String> parsedVoters = {};
    String devName = '';
    try {
      final pkg = json['package_name'];
      if (pkg != null && pkg.toString().startsWith('{')) {
        final meta = jsonDecode(pkg.toString()) as Map<String, dynamic>;
        if (meta['candidates'] != null && meta['candidates'] is List) {
          final list = meta['candidates'] as List;
          parsedCandidates = list.map((c) => NominationCandidate.fromJson(c as Map<String, dynamic>)).toList();
        }
        if (meta['voters'] != null) {
          if (meta['voters'] is Map) {
            (meta['voters'] as Map).forEach((k, v) {
              parsedVoters[k.toString()] = v?.toString() ?? '';
            });
          } else if (meta['voters'] is List) {
            for (var v in (meta['voters'] as List)) {
              parsedVoters[v.toString()] = '';
            }
          }
        }
        if (meta['developerProfile'] != null && meta['developerProfile'] is Map) {
          final p = meta['developerProfile'] as Map<String, dynamic>;
          devName = p['name']?.toString() ?? '';
        } else if (meta['developerName'] != null) {
          devName = meta['developerName'].toString();
        } else if (meta['studioName'] != null) {
          devName = meta['studioName'].toString();
        }
      }
    } catch (e) {
      print('Error parsing nomination candidates: $e');
    }

    if (devName.trim().isEmpty) {
      final email = json['developer_email']?.toString() ?? '';
      if (email.contains('amr01068') || email.contains('kko')) {
        devName = 'kko studio EGYPT';
      } else if (email.isNotEmpty) {
        devName = email;
      } else {
        devName = 'kko studio EGYPT';
      }
    }

    return NominationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'استفتاء وترشيح جديد',
      description: json['description']?.toString() ?? '',
      developerEmail: json['developer_email']?.toString() ?? '',
      developerName: devName,
      candidates: parsedCandidates,
      voters: parsedVoters,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() 
          : DateTime.now(),
    );
  }
}
