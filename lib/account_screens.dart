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
        title: Text(
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
                          Text(
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
                          color: AppColors.surfaceCard,
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
                                    style: TextStyle(
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
        title: Text(
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
                              Text(
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
                                  color: AppColors.surfaceCard,
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
                                            style: TextStyle(
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
          style: TextStyle(
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
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.question,
                  style: TextStyle(
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
          SnackBar(
            content: Text(
              'Could not open your email app. Support address copied to clipboard.',
            ),
            backgroundColor: AppColors.divider,
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      await Clipboard.setData(const ClipboardData(text: _kSupportEmail));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open your email app. Support address copied to clipboard.',
          ),
          backgroundColor: AppColors.divider,
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
          backgroundColor: AppColors.divider,
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
        backgroundColor: AppColors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: TextStyle(
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
        title: Text(
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
          Text(
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
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
          Text(
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
              color: AppColors.surfaceCard,
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
          Text(
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
          Text(
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
            style: TextStyle(
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
        color: AppColors.surfaceCard,
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
            style: TextStyle(
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
        color: AppColors.surfaceCard,
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
          style: TextStyle(
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

// ─────────────────────────────────────────────
//  FESTIVAL HISTORY SCREEN
// ─────────────────────────────────────────────

DateTime? _parseHistoryDate(String? s) {
  if (s == null || s.isEmpty || s == 'TBA') return null;
  final parts = s.split('/');
  if (parts.length == 3) {
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d != null && m != null && y != null) return DateTime(y, m, d);
  }
  return DateTime.tryParse(s);
}

class FestivalHistoryScreen extends StatelessWidget {
  const FestivalHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Festival History',
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
              child: Text('Please log in to view your history.',
                  style: TextStyle(color: AppColors.grey)))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tickets')
                  .where('userId', isEqualTo: uid)
                  .where('status', isEqualTo: 'confirmed')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                final today = DateTime.now();
                final todayStart =
                    DateTime(today.year, today.month, today.day);

                // Only tickets whose event date has passed
                final pastTickets =
                    (snapshot.data?.docs ?? []).where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final date = _parseHistoryDate(
                      data['eventDate']?.toString());
                  return date != null && date.isBefore(todayStart);
                }).toList()
                      ..sort((a, b) {
                        final da = _parseHistoryDate(
                            (a.data()
                                as Map<String, dynamic>)['eventDate']
                                ?.toString());
                        final db = _parseHistoryDate(
                            (b.data()
                                as Map<String, dynamic>)['eventDate']
                                ?.toString());
                        if (da == null && db == null) return 0;
                        if (da == null) return 1;
                        if (db == null) return -1;
                        return db.compareTo(da); // most recent first
                      });

                if (pastTickets.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_rounded,
                              size: 64, color: AppColors.grey600),
                          const SizedBox(height: 16),
                          Text(
                            'No festival history yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Festivals you attended will appear here after they end.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  itemCount: pastTickets.length,
                  itemBuilder: (context, index) {
                    final ticket = pastTickets[index].data()
                        as Map<String, dynamic>;
                    return _HistoryTicketCard(ticket: ticket);
                  },
                );
              },
            ),
    );
  }
}

class _HistoryTicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  const _HistoryTicketCard({required this.ticket});

  Future<void> _openDetail(BuildContext context) async {
    final eventId = ticket['eventId']?.toString() ?? '';
    if (eventId.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .get();
    if (!context.mounted) return;
    if (doc.exists) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(
            eventId: eventId,
            event: doc.data() as Map<String, dynamic>,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final title = ticket['eventTitle']?.toString() ?? 'Untitled Event';
    final date = ticket['eventDate']?.toString() ?? '';
    final tier = ticket['ticketTier']?.toString();
    final amount = (ticket['amount'] as num?)?.toDouble() ?? 0;
    final qty = (ticket['quantity'] as num?)?.toInt() ?? 1;

    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.divider),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.grey600.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.festival_rounded,
                    color: AppColors.grey600, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                AppColors.grey600.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Attended',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.grey600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Tier + amount
                    Row(
                      children: [
                        if (tier != null && tier.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tier,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          amount == 0
                              ? 'Free · $qty pax'
                              : 'RM ${amount.toStringAsFixed(0)} · $qty pax',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    if (date.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 11, color: AppColors.grey),
                          const SizedBox(width: 3),
                          Text(date,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.grey)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

