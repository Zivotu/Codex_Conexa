import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/localization_service.dart';
import '../services/user_service.dart' as user_service;

class AffiliateDashboardScreen extends StatefulWidget {
  const AffiliateDashboardScreen({super.key});

  @override
  _AffiliateDashboardScreenState createState() =>
      _AffiliateDashboardScreenState();
}

class _AffiliateDashboardScreenState extends State<AffiliateDashboardScreen> {
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _userService = user_service.UserService();

  bool _loading = true;
  bool _active = false;
  String _code = '';
  DateTime? _startedAt;
  List<Map<String, dynamic>> _activations = [];

  String _reason = '';
  String? _profileImageUrl;
  String? _displayName;

  @override
  void initState() {
    super.initState();
    _loadAffiliateData();
  }

  Future<void> _loadAffiliateData() async {
    final uid = _auth.currentUser?.uid;
    final loc = Provider.of<LocalizationService>(context, listen: false);
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    // load affiliate doc
    final q = await _fire
        .collection('affiliate_bonus_codes')
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();

    if (q.docs.isNotEmpty) {
      final doc = q.docs.first;
      final data = doc.data();
      _code = data['code'] as String? ?? '';
      _startedAt = (data['createdAt'] as Timestamp?)?.toDate();
      _active = data['active'] as bool? ?? true;

      final snaps = await doc.reference
          .collection('redemptions')
          .orderBy('timestamp', descending: true)
          .get();

      _activations = await Future.wait(snaps.docs.map((d) async {
        final dm = d.data();
        final locId = dm['locationId'] as String? ?? '';
        // fetch location document to get expiry and image
        final locDoc = await _fire.collection('locations').doc(locId).get();
        final locData = locDoc.data() ?? {};
        return {
          'timestamp': (dm['timestamp'] as Timestamp).toDate(),
          'locationName': dm['locationName'] as String? ?? '',
          'locationAddress': dm['locationAddress'] as String? ?? '',
          'expiresAt': (locData['activeUntil'] as Timestamp?)?.toDate(),
          'imagePath': locData['imagePath'] as String? ?? '',
        };
      }).toList());
    }

    // load profile
    final user = _auth.currentUser;
    if (user != null) {
      final userData = await _userService.getUserDocument(user);
      if (userData != null) {
        _displayName = userData['displayName'] as String? ?? '';
        _profileImageUrl = (userData['profileImageUrl'] as String?)?.trim();
      }
    }

    setState(() => _loading = false);
  }

  Future<void> _endPartnership() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final loc = Provider.of<LocalizationService>(context, listen: false);

    // ask reason
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.translate('end_affiliate_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loc.translate('end_affiliate_prompt')),
            TextField(
              decoration: InputDecoration(
                  hintText: loc.translate('end_affiliate_reason')),
              onChanged: (v) => _reason = v,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(loc.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(loc.translate('confirm')),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final batch = _fire.batch();
    batch.update(_fire.collection('users').doc(uid), {
      'affiliateActive': false,
      'affiliateEndedAt': FieldValue.serverTimestamp(),
      'affiliateEndReason': _reason,
    });
    final codeQ = await _fire
        .collection('affiliate_bonus_codes')
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();
    if (codeQ.docs.isNotEmpty) {
      batch.update(codeQ.docs.first.reference, {'active': false});
    }
    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.translate('affiliate_ended'))),
    );
    setState(() => _active = false);
  }

  bool _isNetwork(String path) => path.startsWith('http');

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final count = _activations.length;
    final earnings = count * 70;
    final started = _startedAt != null
        ? DateFormat.yMMMd(loc.currentLanguage).format(_startedAt!)
        : '-';

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('affiliate_dashboard')),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'end') _endPartnership();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'end',
                child: Text(loc.translate('end_affiliate')),
              ),
            ],
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // profile row
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage:
                      (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                          ? (_isNetwork(_profileImageUrl!)
                              ? NetworkImage(_profileImageUrl!)
                              : AssetImage(_profileImageUrl!) as ImageProvider)
                          : const AssetImage('assets/images/default_user.png'),
                ),
                const SizedBox(width: 12),
                Text(
                  _displayName ?? loc.translate('unknownUser'),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // a fixed-height grid to avoid overflow
            SizedBox(
              height: 240,
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildMetricCard(loc.translate('your_bonus_code'), _code),
                  _buildMetricCard(loc.translate('member_since'), started),
                  _buildMetricCard(
                      loc.translate('total_activations'), '$count'),
                  _buildMetricCard(
                      loc.translate('total_earnings'), '€$earnings'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // promotional button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => launchUrl(
                  Uri.parse('https://conexa.life'),
                  mode: LaunchMode.externalApplication,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(loc.translate('promotional_materials')),
              ),
            ),
            const SizedBox(height: 12),

            // questions button, now green
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showFeedbackForm(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(loc.translate('post_question_or_suggestion')),
              ),
            ),

            const SizedBox(height: 32),

            // acquisitions
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                loc.translate('your_acquisitions'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: _activations.map((act) {
                final acquired = DateFormat.yMMMd(loc.currentLanguage)
                    .format(act['timestamp']);
                final expires = act['expiresAt'] != null
                    ? DateFormat.yMMMd(loc.currentLanguage)
                        .format(act['expiresAt'])
                    : loc.translate('no_expiry');
                final img = act['imagePath'] as String;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: img.isNotEmpty
                          ? (_isNetwork(img)
                              ? Image.network(img,
                                  width: 60, height: 60, fit: BoxFit.cover)
                              : Image.asset(img,
                                  width: 60, height: 60, fit: BoxFit.cover))
                          : const SizedBox(width: 60, height: 60),
                    ),
                    title: Text(act['locationName']),
                    subtitle: Text(
                      '${loc.translate('acquired_on')}: $acquired\n'
                      '${loc.translate('expires_on')}: $expires',
                    ),
                    isThreeLine: true,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // feedback dialog
  void _showFeedbackForm(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.translate('post_question_or_suggestion')),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration:
              InputDecoration(hintText: loc.translate('enter_your_text_here')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final uid = _auth.currentUser?.uid;
              if (uid != null) {
                final snap = await _fire
                    .collection('affiliate_bonus_codes')
                    .where('userId', isEqualTo: uid)
                    .limit(1)
                    .get();
                if (snap.docs.isNotEmpty) {
                  await snap.docs.first.reference.collection('feedback').add({
                    'text': ctrl.text,
                    'timestamp': Timestamp.now(),
                  });
                }
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(loc.translate('thank_you_feedback'))),
              );
            },
            child: Text(loc.translate('send')),
          ),
        ],
      ),
    );
  }
}
