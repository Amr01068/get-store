import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/nomination_model.dart';
import 'models/app_model.dart';
import 'services/api_service.dart';

class NominationsScreen extends StatefulWidget {
  const NominationsScreen({super.key});

  @override
  State<NominationsScreen> createState() => _NominationsScreenState();
}

class _NominationsScreenState extends State<NominationsScreen> {
  List<NominationModel> _nominations = [];
  bool _isLoading = true;
  final Map<String, String> _votedMap = {}; // nominationId -> votedCandidateId
  final Set<String> _votingInProgress = {}; // candidateId being voted

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await ApiService.getDeviceId();
    final list = await ApiService.fetchActiveNominations();

    final Map<String, String> votes = {};
    for (var nom in list) {
      final serverCandidate = nom.getDeviceVotedCandidate(deviceId);
      final localCandidate = prefs.getString('voted_nomination_${nom.id}');

      if (serverCandidate != null && serverCandidate.isNotEmpty) {
        votes[nom.id] = serverCandidate;
        await prefs.setString('voted_nomination_${nom.id}', serverCandidate);
      } else if (nom.hasDeviceVoted(deviceId)) {
        votes[nom.id] = (localCandidate != null && localCandidate.isNotEmpty) ? localCandidate : 'voted';
      } else if (localCandidate != null && localCandidate.isNotEmpty) {
        // إذا كان الاستفتاء في السيرفر لا يحتوي على تصويت من هذا الجهاز، نزيل الكاش المحلي
        await prefs.remove('voted_nomination_${nom.id}');
      }
    }

    if (mounted) {
      setState(() {
        _nominations = list;
        _votedMap.clear();
        _votedMap.addAll(votes);
        _isLoading = false;
      });
    }
  }

  Future<void> _handleVote(NominationModel nomination, NominationCandidate candidate) async {
    final deviceId = await ApiService.getDeviceId();
    final previousCandidateId = _votedMap[nomination.id];

    setState(() {
      _votingInProgress.add(candidate.id);
    });

    final result = await ApiService.toggleOrSwitchVote(nomination.id, candidate.id, deviceId);

    if (result.success) {
      final prefs = await SharedPreferences.getInstance();

      if (mounted) {
        setState(() {
          _votingInProgress.remove(candidate.id);

          Map<String, String> updatedVoters = Map<String, String>.from(nomination.voters);

          if (result.actionType == VoteActionType.unvoted) {
            // 1. إلغاء التصويت بالكامل
            _votedMap.remove(nomination.id);
            prefs.remove('voted_nomination_${nomination.id}');
            updatedVoters.remove(deviceId);
          } else {
            // 2. تصويت جديد أو تبديل للمرشح الآخر
            _votedMap[nomination.id] = candidate.id;
            prefs.setString('voted_nomination_${nomination.id}', candidate.id);
            updatedVoters[deviceId] = candidate.id;
          }

          // تحديث عدادات الأصوات محلياً وفورياً
          final updatedCandidates = nomination.candidates.map((c) {
            if (result.actionType == VoteActionType.unvoted) {
              if (c.id == candidate.id) {
                return c.copyWith(votes: max(0, c.votes - 1));
              }
            } else if (result.actionType == VoteActionType.switched) {
              if (c.id == previousCandidateId) {
                return c.copyWith(votes: max(0, c.votes - 1));
              } else if (c.id == candidate.id) {
                return c.copyWith(votes: c.votes + 1);
              }
            } else {
              // تصويت جديد
              if (c.id == candidate.id) {
                return c.copyWith(votes: c.votes + 1);
              }
            }
            return c;
          }).toList();

          final index = _nominations.indexWhere((n) => n.id == nomination.id);
          if (index != -1) {
            _nominations[index] = NominationModel(
              id: nomination.id,
              title: nomination.title,
              description: nomination.description,
              developerEmail: nomination.developerEmail,
              developerName: nomination.developerName,
              candidates: updatedCandidates,
              voters: updatedVoters,
              createdAt: nomination.createdAt,
            );
          }
        });

        // رسالة تأكيد لطيفة حسب نوع الإجراء
        if (result.actionType == VoteActionType.unvoted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF222222),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              content: Row(
                children: [
                  const Icon(Icons.remove_circle_outline, color: Colors.amberAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'تم إلغاء تصويتك لـ "${candidate.name}" ↩️',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else if (result.actionType == VoteActionType.switched) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.teal[800],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              content: Row(
                children: [
                  const Icon(Icons.swap_horiz_rounded, color: Colors.tealAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'تم تحويل وتغيير صوتك إلى "${candidate.name}" بنجاح! 🔄',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.teal,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'تم تسجيل صوتك لـ "${candidate.name}" بنجاح! 🌟',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } else {
      if (mounted) {
        setState(() => _votingInProgress.remove(candidate.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(result.message.isNotEmpty ? result.message : 'تعذر إتمام العملية، يرجى المحاولة لاحقاً.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.poll_rounded, color: Colors.tealAccent),
            SizedBox(width: 10),
            Text(
              'ترشيحات واستطلاع الرأي',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
          : RefreshIndicator(
              color: Colors.tealAccent,
              backgroundColor: Colors.grey[900],
              onRefresh: _loadData,
              child: _nominations.isEmpty ? _buildEmptyState() : _buildNominationsList(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.how_to_vote_outlined, size: 60, color: Colors.tealAccent),
            ),
            const SizedBox(height: 20),
            const Text(
              'لا توجد ترشيحات نشطة حالياً',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'ترقبوا الاستفتاءات القادمة لاختيار وتصويت تطبيقاتكم وألعابكم المفضلة!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNominationsList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _nominations.length,
      itemBuilder: (context, index) {
        final nomination = _nominations[index];
        final hasVoted = _votedMap.containsKey(nomination.id);
        final votedCandId = _votedMap[nomination.id];
        final totalVotes = nomination.totalVotes;

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[850]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Badge & Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.poll_outlined,
                          size: 14,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'إجمالي الأصوات: $totalVotes',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                nomination.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              if (nomination.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  nomination.description,
                  style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                ),
              ],
              if (nomination.developerName.isNotEmpty || nomination.developerEmail.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.account_circle_outlined, size: 14, color: Colors.tealAccent),
                    const SizedBox(width: 5),
                    Text(
                      'الناشر: ${nomination.developerName.isNotEmpty ? nomination.developerName : nomination.developerEmail}',
                      style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 16),

              // Candidates List
              ...nomination.candidates.map((candidate) {
                final isMyChoice = hasVoted && votedCandId == candidate.id;
                final isVoting = _votingInProgress.contains(candidate.id);
                final percent = totalVotes > 0 ? (candidate.votes / totalVotes) : 0.0;
                final percentInt = (percent * 100).round();
                final isGame = candidate.type == 'game';

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: isMyChoice 
                        ? const Color(0xFF1A2E28) 
                        : const Color(0xFF242424),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isMyChoice ? const Color(0xFF00897B) : const Color(0xFF333333),
                      width: isMyChoice ? 1.5 : 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: isVoting ? null : () => _handleVote(nomination, candidate),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CandidateDetailsScreen(candidate: candidate),
                                      ),
                                    );
                                  },
                                  child: Hero(
                                    tag: 'candidate_img_${candidate.id}',
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: buildAppImage(
                                        candidate.image,
                                        width: 55,
                                        height: 55,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 55,
                                          height: 55,
                                          color: Colors.grey[800],
                                          child: Icon(
                                            isGame ? Icons.videogame_asset : Icons.apps,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              candidate.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isGame 
                                                  ? const Color(0xFF3E2723) 
                                                  : const Color(0xFF1A237E),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isGame ? 'لعبة' : 'تطبيق',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isGame ? Colors.orange[200] : Colors.lightBlue[200],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        candidate.description,
                                        style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.3),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // إذا كان المستخدم قد قام بالتصويت في هذا الاستفتاء
                            if (hasVoted) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (isMyChoice)
                                    const Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 14),
                                        SizedBox(width: 4),
                                        Text(
                                          'اختيارك الحالي',
                                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    )
                                  else
                                    const SizedBox(),
                                  Text(
                                    '$percentInt% (${candidate.votes} صوت)',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percent,
                                  minHeight: 8,
                                  backgroundColor: Colors.black45,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isMyChoice ? const Color(0xFF00897B) : (isGame ? Colors.orange[700]! : Colors.blue[700]!),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // أزرار عادية مليانة من الداخل وبخط أبيض
                              if (isMyChoice)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: isVoting ? null : () => _handleVote(nomination, candidate),
                                    icon: isVoting 
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                                    label: Text(
                                      isVoting ? 'جاري الإلغاء...' : 'إلغاء التصويت',
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFC62828), // أحمر مليان عادي
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                )
                              else
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: isVoting ? null : () => _handleVote(nomination, candidate),
                                    icon: isVoting 
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.swap_horiz_rounded, size: 16, color: Colors.white),
                                    label: Text(
                                      isVoting ? 'جاري التحويل...' : 'تحويل التصويت لهذا الخيار',
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1565C0), // أزرق مليان عادي
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),
                            ] else ...[
                              // الزر الأساسي للتصويت لأول مرة: زر مليان عادي بخط أبيض
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: isVoting ? null : () => _handleVote(nomination, candidate),
                                  icon: isVoting 
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.how_to_vote, size: 16, color: Colors.white),
                                  label: Text(
                                    isVoting ? 'جاري التسجيل...' : 'صوّت لهذا الخيار',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00796B), // أخضر تيل مليان عادي
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }
}

class CandidateDetailsScreen extends StatelessWidget {
  final NominationCandidate candidate;

  const CandidateDetailsScreen({super.key, required this.candidate});

  @override
  Widget build(BuildContext context) {
    final isGame = candidate.type == 'game';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF161616),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E1E1E),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            candidate.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // صورة المرشح بشكل أكبر
                Center(
                  child: Hero(
                    tag: 'candidate_img_${candidate.id}',
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: isGame 
                              ? Colors.orangeAccent.withOpacity(0.5) 
                              : Colors.cyanAccent.withOpacity(0.5),
                          width: 2.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(21),
                        child: buildAppImage(
                          candidate.image,
                          width: 240,
                          height: 240,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF262626),
                            child: Icon(
                              isGame ? Icons.videogame_asset : Icons.apps,
                              size: 90,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),

                // الاسم
                Text(
                  candidate.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 18),

                // الوصف
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    candidate.description.trim().isNotEmpty
                        ? candidate.description
                        : 'لا يوجد وصف متاح لهذا المرشح حالياً.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 15,
                      height: 1.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
