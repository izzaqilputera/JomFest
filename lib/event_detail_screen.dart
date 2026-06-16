import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'payment_screen.dart';
import 'theme.dart';

/// Formats a price for display (2000.0 -> "2000", 1500.5 -> "1500.5").
String _formatTierPrice(double p) =>
    p == p.roundToDouble() ? p.toInt().toString() : p.toString();

/// Reads the ticket tiers from an event map, falling back to the legacy
/// single `ticketPrice` field for older events without `ticketTiers`.
List<Map<String, dynamic>> _extractTiers(Map<String, dynamic> event) {
  final raw = event['ticketTiers'];
  if (raw is List && raw.isNotEmpty) {
    return raw.whereType<Map>().map((e) {
      final price = e['price'];
      return <String, dynamic>{
        'name': (e['name'] ?? 'Standard').toString(),
        'price':
            price is num ? price.toDouble() : double.tryParse('$price') ?? 0.0,
      };
    }).toList();
  }
  final p = event['ticketPrice'];
  final price = p is num ? p.toDouble() : double.tryParse('$p') ?? 0.0;
  return [
    {'name': price == 0 ? 'Free Entry' : 'Standard', 'price': price}
  ];
}

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> event;

  const EventDetailScreen({
    super.key,
    required this.eventId,
    required this.event,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isBookmarked = false;
  int _selectedTierIndex = 0;
  final uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _checkBookmark();
    _logView();
  }

  Future<void> _checkBookmark() async {
    final doc = await FirebaseFirestore.instance
        .collection('bookmarks')
        .doc('${uid}_${widget.eventId}')
        .get();
    if (mounted) setState(() => _isBookmarked = doc.exists);
  }

  Future<void> _logView() async {
    await FirebaseFirestore.instance
        .collection('interactions')
        .add({
      'uid': uid,
      'eventId': widget.eventId,
      'type': 'view',
      'category': widget.event['category'],
      'featureVector': widget.event['featureVector'],
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _toggleBookmark() async {
    final docRef = FirebaseFirestore.instance
        .collection('bookmarks')
        .doc('${uid}_${widget.eventId}');

    if (_isBookmarked) {
      await docRef.delete();
      setState(() => _isBookmarked = false);
    } else {
      await docRef.set({
        'uid': uid,
        'eventId': widget.eventId,
        'event': widget.event,
        'savedAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance
          .collection('interactions')
          .add({
        'uid': uid,
        'eventId': widget.eventId,
        'type': 'bookmark',
        'category': widget.event['category'],
        'featureVector': widget.event['featureVector'],
        'timestamp': FieldValue.serverTimestamp(),
      });
      setState(() => _isBookmarked = true);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isBookmarked
              ? 'Event bookmarked!'
              : 'Bookmark removed'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildDetailEventImage(String? imageUrl) {
    final hasImage =
        imageUrl != null && (imageUrl as String).isNotEmpty;

    if (!hasImage) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primaryLight,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Icon(Icons.festival,
                  size: 70, color: AppColors.white.withOpacity(0.54)),
            ],
          ),
        ),
      );
    }

    // Check if it's a base64 data URL
    if (imageUrl.startsWith('data:image')) {
      try {
        final base64String = imageUrl
            .replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDetailImagePlaceholder();
          },
        );
      } catch (e) {
        return _buildDetailImagePlaceholder();
      }
    } else {
      // It's a network URL (if any)
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDetailImagePlaceholder();
        },
      );
    }
  }

  Widget _buildDetailImagePlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryLight,
          ],
        ),
      ),
      child: Center(
        child: Icon(Icons.festival,
            size: 70, color: AppColors.white.withOpacity(0.54)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final tiers = _extractTiers(event);
    if (_selectedTierIndex >= tiers.length) _selectedTierIndex = 0;
    final selectedTier = tiers[_selectedTierIndex];
    final selectedPrice = selectedTier['price'] as double;
    final hasMultipleTiers = tiers.length > 1;
    final keywords = event['keywords'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            actions: [
              IconButton(
                icon: Icon(
                  _isBookmarked
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  color: AppColors.white,
                ),
                onPressed: _toggleBookmark,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildDetailEventImage(event['imageUrl']),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category + Type badges
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          event['category'] ?? 'General',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          event['type'] ?? 'In Person',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    event['title'] ?? 'Untitled Event',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Info card
                  _buildInfoCard([
                    _buildInfoRow(
                        Icons.business_outlined,
                        'Organizer',
                        event['organizerName'] ?? 'Unknown'),
                    _buildInfoRow(
                        Icons.location_on_outlined,
                        'Location',
                        event['location'] ?? 'Unknown'),
                    if (event['venue'] != null &&
                        event['venue'].toString().isNotEmpty)
                      _buildInfoRow(Icons.place_outlined,
                          'Venue', event['venue']),
                    _buildInfoRow(
                        Icons.calendar_today_outlined,
                        'Start Date',
                        event['startDate'] ?? 'TBA'),
                    _buildInfoRow(Icons.event_outlined,
                        'End Date', event['endDate'] ?? 'TBA'),
                  ]),
                  const SizedBox(height: 16),

                  // Ticket categories selector (only when more than one tier)
                  if (hasMultipleTiers) ...[
                    const Text(
                      'Select Ticket Category',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...tiers.asMap().entries.map((entry) {
                      final i = entry.key;
                      final tier = entry.value;
                      final tierPrice = tier['price'] as double;
                      final selected = i == _selectedTierIndex;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedTierIndex = i),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primarySurface
                                : AppColors.scaffoldBg,
                            borderRadius:
                                BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.divider,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                size: 20,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.grey,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  tier['name'] as String,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                tierPrice == 0
                                    ? 'FREE'
                                    : 'RM ${_formatTierPrice(tierPrice)}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: tierPrice == 0
                                      ? AppColors.success
                                      : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],

                  // Description
                  if (event['description'] != null &&
                      event['description']
                          .toString()
                          .isNotEmpty) ...[
                    const Text(
                      'About this event',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event['description'],
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.grey700,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Keywords/Tags
                  if (keywords.isNotEmpty) ...[
                    const Text(
                      'Tags',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: keywords
                          .map((k) => Container(
                        padding:
                        const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6),
                        decoration: BoxDecoration(
                          color:
                          AppColors.primarySurface,
                          borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          k.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),

      // Bottom bar with price + buy button
      bottomNavigationBar: Container(
        padding: AppSpacing.cardPadding,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasMultipleTiers
                      ? selectedTier['name'] as String
                      : 'Ticket Price',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.grey),
                ),
                Text(
                  selectedPrice == 0
                      ? 'FREE'
                      : 'RM ${_formatTierPrice(selectedPrice)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: selectedPrice == 0
                        ? AppColors.success
                        : AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaymentScreen(
                          eventId: widget.eventId,
                          event: widget.event,
                          amount: selectedPrice,
                          tierName: hasMultipleTiers
                              ? selectedTier['name'] as String
                              : null,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    selectedPrice == 0
                        ? 'Get Free Ticket'
                        : 'Buy Ticket',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> rows) {
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: rows
            .expand((row) => [row, const SizedBox(height: 10)])
            .toList()
          ..removeLast(),
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 13, color: AppColors.grey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}