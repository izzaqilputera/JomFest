import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'event_detail_screen.dart';
import 'theme.dart';


const String _kSupportEmail = 'support@jomfest.app';


class HelpArticle {
  final String question;
  final String answer;
  const HelpArticle(this.question, this.answer);
}

final List<HelpArticle> _accountHelpArticles = const [
  HelpArticle(
    'I cannot sign in',
    'On the login screen, use “Forgot password?” to reset your Firebase account '
        'email. If email sign-in still fails, check spam for the reset link, wait a '
        'few minutes, and try again on a stable connection.',
  ),
  HelpArticle(
    'Update my profile or photo',
    'Open the Account tab, then edit your name, location, or profile photo. '
        'Changes save to your profile and improve recommendations.',
  ),
  HelpArticle(
    'Personalise “For You”',
    'Add your interests under Account. The For You tab uses those interests '
        'together with events you view or bookmark to suggest festivals you may like.',
  ),
];

final List<HelpArticle> _ticketsHelpArticles = const [
  HelpArticle(
    'Where is my ticket or QR code?',
    'After a successful payment, open the Tickets tab in the bottom navigation. '
        'Each purchase shows a QR code for check-in at the venue.',
  ),
  HelpArticle(
    'Payments and checkout',
    'Checkout opens in your browser (ToyyibPay). FPX, cards, and supported '
        'e-wallets are available depending on the event. Complete payment in the '
        'same session; return to the app and use “Verify payment” if needed.',
  ),
  HelpArticle(
    'Refunds and cancellations',
    'Refund rules depend on the event organiser. For refund requests or '
        'postponements, email support with the event name, date, and any order or '
        'payment reference you have.',
  ),
];

final List<HelpArticle> _eventsHelpArticles = const [
  HelpArticle(
    'Discover vs For You',
    'Discover lists published festivals you can filter and search. For You ranks '
        'events based on your interests and activity so favourites rise to the top.',
  ),
  HelpArticle(
    'Save events',
    'On an event page, use the bookmark control to save it. Open Saved Events from '
        'your Account tab to see them in one place.',
  ),
  HelpArticle(
    'Event information',
    'Tap any event card for full details: date, location, price, organiser, and '
        'description. Contact the organiser for lineup or accessibility questions.',
  ),
];

final List<HelpArticle> _quickFaqItems = const [
  HelpArticle(
    'The app feels stuck or data looks old',
    'Fully close JomFest and reopen it. On poor networks, images and tickets may '
        'take a few seconds to refresh.',
  ),
  HelpArticle(
    'I am an organiser',
    'Organisers use the separate organiser flow after registration is approved. '
        'If your application is pending or rejected, check your email or contact '
        'support with the email you used to apply.',
  ),
];

class SavedEventsScreen extends StatelessWidget {
  const SavedEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text(
          'Saved Events',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.scaffoldBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: uid == null
          ? const Center(
              child: Text(
                'Please log in to view saved events',
                style: TextStyle(color: AppColors.grey),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookmarks')
                  .where('uid', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.favorite_outline_rounded,
                              size: 60, color: AppColors.grey600),
                          const SizedBox(height: 16),
                          const Text(
                            'No saved events yet',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Bookmark an event to see it here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final bookmarks = docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final event = (data['event'] as Map<String, dynamic>?) ?? {};
                  return {
                    'eventId': data['eventId']?.toString() ?? '',
                    'event': event,
                    'savedAt': data['savedAt'],
                  };
                }).toList()
                  ..sort((a, b) {
                    final aTs = a['savedAt'] as Timestamp?;
                    final bTs = b['savedAt'] as Timestamp?;
                    if (aTs == null && bTs == null) return 0;
                    if (aTs == null) return 1;
                    if (bTs == null) return -1;
                    return bTs.compareTo(aTs);
                  });

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  itemCount: bookmarks.length,
                  itemBuilder: (context, index) {
                    final item = bookmarks[index];
                    final event = item['event'] as Map<String, dynamic>;
                    final eventId = item['eventId'] as String;
                    final title = event['title']?.toString() ?? 'Untitled Event';
                    final location = event['location']?.toString() ?? 'Unknown';
                    final date = event['startDate']?.toString() ?? '';

                    return GestureDetector(
                      onTap: eventId.isEmpty
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EventDetailScreen(
                                    eventId: eventId,
                                    event: event,
                                  ),
                                ),
                              );
                            },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161616),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.festival_rounded,
                                  color: AppColors.primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.grey),
                                  ),
                                  if (date.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      date,
                                      style: const TextStyle(
                                          fontSize: 11, color: AppColors.grey),
                                    ),
                                  ]
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                FirebaseFirestore.instance
                                    .collection('bookmarks')
                                    .doc('${uid}_$eventId')
                                    .delete();
                              },
                              icon: const Icon(Icons.bookmark,
                                  color: AppColors.primary),
                              tooltip: 'Remove bookmark',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static String _daysLabel(String? dateStr) {
    if (dateStr == null) return '';
    final parts = dateStr.split('/');
    if (parts.length != 3) return '';
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return '';
    final eventDate = DateTime(year, month, day);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final diff = eventDate.difference(today).inDays;
    if (diff < 0) return 'Event passed';
    if (diff == 0) return 'Today!';
    if (diff == 1) return 'Tomorrow!';
    return 'In $diff days';
  }

  Future<void> _clear(String uid, String ticketId) async {
    await FirebaseFirestore.instance
        .collection('clearedNotifications')
        .doc('${uid}_$ticketId')
        .set({
      'uid': uid,
      'ticketId': ticketId,
      'clearedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _clearAll(String uid, List<String> ticketIds) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final id in ticketIds) {
      batch.set(
        FirebaseFirestore.instance.collection('clearedNotifications').doc('${uid}_$id'),
        {'uid': uid, 'ticketId': id, 'clearedAt': FieldValue.serverTimestamp()},
      );
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.scaffoldBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: uid == null
          ? const Center(
              child: Text('Please log in to view notifications',
                  style: TextStyle(color: AppColors.grey)),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clearedNotifications')
                  .where('uid', isEqualTo: uid)
                  .snapshots(),
              builder: (context, clearedSnap) {
                final clearedIds = clearedSnap.data?.docs
                        .map((d) => (d.data() as Map<String, dynamic>)['ticketId'] as String?)
                        .whereType<String>()
                        .toSet() ??
                    <String>{};

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('tickets')
                      .where('uid', isEqualTo: uid)
                      .where('status', isEqualTo: 'confirmed')
                      .snapshots(),
                  builder: (context, ticketsSnap) {
                    if (ticketsSnap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(color: AppColors.primary));
                    }

                    final visible = (ticketsSnap.data?.docs ?? [])
                        .where((d) => !clearedIds.contains(d.id))
                        .toList();

                    if (visible.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_outlined,
                                  size: 60, color: AppColors.grey600),
                              const SizedBox(height: 16),
                              const Text(
                                'No notifications',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Event updates and reminders will appear here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final visibleIds = visible.map((d) => d.id).toList();

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${visible.length} reminder${visible.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                    fontSize: 13, color: AppColors.grey),
                              ),
                              TextButton(
                                onPressed: () => _clearAll(uid, visibleIds),
                                child: const Text(
                                  'Clear all',
                                  style: TextStyle(
                                      fontSize: 13, color: AppColors.grey),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final doc = visible[index];
                              final ticket = doc.data() as Map<String, dynamic>;
                              final ticketId = doc.id;
                              final eventTitle =
                                  ticket['eventTitle'] as String? ?? 'Event';
                              final eventDate = ticket['eventDate'] as String?;
                              final venue = ticket['venue'] as String? ?? '';
                              final label = _daysLabel(eventDate);
                              final isPassed = label == 'Event passed';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161616),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: isPassed
                                            ? AppColors.grey.withValues(alpha: 0.12)
                                            : AppColors.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        isPassed
                                            ? Icons.event_available_rounded
                                            : Icons.event_rounded,
                                        color: isPassed
                                            ? AppColors.grey
                                            : AppColors.primary,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isPassed
                                                ? 'Past Event'
                                                : 'Upcoming Event Reminder',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isPassed
                                                  ? AppColors.grey
                                                  : AppColors.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            eventTitle,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          if (eventDate != null) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(
                                                    Icons.calendar_today_outlined,
                                                    size: 11,
                                                    color: AppColors.grey),
                                                const SizedBox(width: 4),
                                                Text(eventDate,
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors.grey)),
                                                if (label.isNotEmpty) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isPassed
                                                          ? AppColors.grey.withValues(alpha: 0.12)
                                                          : AppColors.primarySurface,
                                                      borderRadius:
                                                          BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      label,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                        color: isPassed
                                                            ? AppColors.grey
                                                            : AppColors.primary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                          if (venue.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                const Icon(
                                                    Icons.location_on_outlined,
                                                    size: 11,
                                                    color: AppColors.grey),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    venue,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors.grey),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _clear(uid, ticketId),
                                      icon: const Icon(Icons.close_rounded,
                                          size: 18, color: AppColors.grey),
                                      tooltip: 'Clear',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 32, minHeight: 32),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}

class HelpTopicScreen extends StatelessWidget {
  final String title;
  final List<HelpArticle> items;

  const HelpTopicScreen({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.scaffoldBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final item = items[i];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.question,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.answer,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.grey,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static Future<void> _openSupportEmail(BuildContext context) async {
    final uri = Uri.parse(
      'mailto:$_kSupportEmail?subject=${Uri.encodeComponent('JomFest — Help request')}',
    );
    try {
      final ok = await launchUrl(uri);
      if (!context.mounted) return;
      if (!ok) {
        await Clipboard.setData(const ClipboardData(text: _kSupportEmail));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open your email app. Support address copied to clipboard.',
            ),
            backgroundColor: Color(0xFF2A2A2A),
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      await Clipboard.setData(const ClipboardData(text: _kSupportEmail));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open your email app. Support address copied to clipboard.',
          ),
          backgroundColor: Color(0xFF2A2A2A),
        ),
      );
    }
  }

  static Future<void> _copySupportEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _kSupportEmail));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied $_kSupportEmail'),
          backgroundColor: const Color(0xFF2A2A2A),
        ),
      );
    }
  }

  static void _showLegalSheet(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            body,
            style: const TextStyle(
              color: AppColors.grey,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text(
          'Help & Support',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.scaffoldBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text(
            'How can we help?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Find answers below or reach our team by email.',
            style: TextStyle(fontSize: 14, color: AppColors.grey, height: 1.35),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.mail_outline_rounded,
                        color: AppColors.primary, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Contact support',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _kSupportEmail,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'We usually reply within 1–2 business days. Include the event name '
                  'and, if relevant, what you were doing in the app when the issue happened.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.grey,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: () => _openSupportEmail(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Email us'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => _copySupportEmail(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.45),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy email address'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Quick tips',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TipRow(
                  icon: Icons.refresh_rounded,
                  text:
                      'Fully close and reopen the app if tickets or images look outdated.',
                ),
                SizedBox(height: 12),
                _TipRow(
                  icon: Icons.wifi_rounded,
                  text:
                      'Use a stable connection when paying or loading event posters.',
                ),
                SizedBox(height: 12),
                _TipRow(
                  icon: Icons.logout_rounded,
                  text:
                      'Sign out and sign back in if your account name or photo does not match what you expect.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Common questions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ..._quickFaqItems.map(
            (qa) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _HelpFaqExpansion(qa: qa),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Browse by topic',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _HelpCategoryTile(
            icon: Icons.lock_outline_rounded,
            title: 'Account & login',
            subtitle: 'Password, profile, For You personalisation',
            articles: _accountHelpArticles,
          ),
          _HelpCategoryTile(
            icon: Icons.confirmation_number_outlined,
            title: 'Tickets & payments',
            subtitle: 'QR tickets, checkout, refunds',
            articles: _ticketsHelpArticles,
          ),
          _HelpCategoryTile(
            icon: Icons.event_available_outlined,
            title: 'Events',
            subtitle: 'Discover, saved events, event details',
            articles: _eventsHelpArticles,
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              TextButton(
                onPressed: () => _showLegalSheet(
                  context,
                  title: 'Terms of service',
                  body: 'These terms are a placeholder for your production app. '
                      'Before launch, replace this text with your real terms covering '
                      'use of JomFest, ticketing, organiser responsibilities, '
                      'limitation of liability, and governing law.',
                ),
                child: const Text('Terms of service'),
              ),
              TextButton(
                onPressed: () => _showLegalSheet(
                  context,
                  title: 'Privacy policy',
                  body: 'This privacy summary is a placeholder. Your final policy '
                      'should describe what data you collect (account, payments, '
                      'usage analytics), how Firebase and payment providers process it, '
                      'retention, and user rights.',
                ),
                child: const Text('Privacy'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'JomFest · version 1.0.0',
            style: TextStyle(fontSize: 12, color: AppColors.grey600),
          ),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary.withValues(alpha: 0.9)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _HelpFaqExpansion extends StatelessWidget {
  final HelpArticle qa;

  const _HelpFaqExpansion({required this.qa});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding:
              const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: AppColors.grey,
          collapsedIconColor: AppColors.grey,
          title: Text(
            qa.question,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                qa.answer,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.grey,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpCategoryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<HelpArticle> articles;

  const _HelpCategoryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.articles,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        onTap: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => HelpTopicScreen(title: title, items: articles),
            ),
          );
        },
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.grey, fontSize: 12),
        ),
        trailing:
            const Icon(Icons.chevron_right_rounded, color: AppColors.grey),
      ),
    );
  }
}

