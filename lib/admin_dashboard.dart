import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:convert';
import 'dart:io';
import 'theme.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: IndexedStack(
        index: _currentNavIndex,
        children: const [
          _OverviewPage(),
          _PendingEventsPage(),
          _OrganizersPage(),
        ],
      ),
      bottomNavigationBar: _AdminNavBar(
        currentIndex: _currentNavIndex,
        onTap: (i) => setState(() => _currentNavIndex = i),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  BOTTOM NAV BAR
// ─────────────────────────────────────────────

class _AdminNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _AdminNavBar(
      {required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItem(icon: Icons.dashboard_rounded, label: 'Overview'),
      _NavItem(icon: Icons.pending_actions_rounded, label: 'Events'),
      _NavItem(icon: Icons.business_rounded, label: 'Organizers'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Badge on Events tab
                      i == 1
                          ? _PendingBadgeIcon(
                              icon: items[i].icon,
                              selected: selected)
                          : Icon(items[i].icon,
                              size: 24,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.grey600),
                      const SizedBox(height: 4),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: selected
                              ? AppColors.primary
                              : AppColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _PendingBadgeIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  const _PendingBadgeIcon(
      {required this.icon, required this.selected});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon,
                size: 24,
                color:
                    selected ? AppColors.primary : AppColors.grey600),
            if (count > 0)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  OVERVIEW PAGE
// ─────────────────────────────────────────────

class _OverviewPage extends StatelessWidget {
  const _OverviewPage();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 28),
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Admin Dashboard',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'JomFest Control Center',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.grey),
                      ),
                    ],
                  ),
                ),
                // Sign out
                GestureDetector(
                  onTap: () async =>
                      await FirebaseAuth.instance.signOut(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.errorSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.error.withOpacity(0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.logout_rounded,
                            size: 14, color: AppColors.error),
                        SizedBox(width: 6),
                        Text('Sign Out',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.error,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Stats grid
            const Text(
              'Platform Stats',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Total Users',
                    icon: Icons.people_rounded,
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .snapshots(),
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Total Events',
                    icon: Icons.festival_rounded,
                    stream: FirebaseFirestore.instance
                        .collection('events')
                        .snapshots(),
                    color: const Color(0xFF57A683),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PendingStatCard(
                    label: 'Pending Events',
                    icon: Icons.pending_actions_rounded,
                    collection: 'events',
                    field: 'status',
                    value: 'pending',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PendingStatCard(
                    label: 'Pending Orgs',
                    icon: Icons.business_rounded,
                    collection: 'organizers',
                    field: 'isVerified',
                    value: false,
                    color: const Color(0xFF60A5FA),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Quick actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _AdminQuickAction(
              icon: Icons.photo_library_rounded,
              label: 'Manage Event Images',
              subtitle: 'Edit the poster image for any event',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageEventImagesScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),

            // Recent activity
            const Text(
              'Recent Events',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                final events = snapshot.data?.docs ?? [];
                if (events.isEmpty) {
                  return const _EmptyState(
                      icon: Icons.festival_rounded,
                      message: 'No events yet');
                }
                return Column(
                  children: events.map((doc) {
                    final e = doc.data() as Map<String, dynamic>;
                    return _RecentEventRow(event: e);
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Stream<QuerySnapshot> stream;
  final Color color;

  const _StatCard(
      {required this.label,
      required this.icon,
      required this.stream,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.grey)),
            ],
          ),
        );
      },
    );
  }
}

class _PendingStatCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String collection;
  final String field;
  final dynamic value;
  final Color color;

  const _PendingStatCard(
      {required this.label,
      required this.icon,
      required this.collection,
      required this.field,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where(field, isEqualTo: value)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: count > 0
                  ? color.withOpacity(0.4)
                  : AppColors.divider,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.grey)),
            ],
          ),
        );
      },
    );
  }
}

class _RecentEventRow extends StatelessWidget {
  final Map<String, dynamic> event;
  const _RecentEventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final status = event['status'] ?? 'pending';
    Color statusColor;
    if (status == 'published') {
      statusColor = AppColors.success;
    } else if (status == 'rejected') {
      statusColor = AppColors.error;
    } else {
      statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.festival_rounded,
                size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['title'] ?? 'Untitled',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event['organizerName'] ?? '',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.grey),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PENDING EVENTS PAGE
// ─────────────────────────────────────────────

class _PendingEventsPage extends StatelessWidget {
  const _PendingEventsPage();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
            child: Row(
              children: [
                const Text(
                  'Pending Events',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('events')
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.docs.length ?? 0;
                    if (count == 0) return const SizedBox();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary));
                }
                final events = snapshot.data?.docs ?? [];
                if (events.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    message: 'No pending events!',
                    subtitle: 'All caught up ✓',
                    iconColor: AppColors.success,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: events.length,
                  itemBuilder: (context, i) {
                    final event =
                        events[i].data() as Map<String, dynamic>;
                    final eventId = events[i].id;
                    return _EventReviewCard(
                        event: event, eventId: eventId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EventReviewCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final String eventId;

  const _EventReviewCard(
      {required this.event, required this.eventId});

  Future<void> _approve(BuildContext context) async {
    await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .update({
      'status': 'published',
      'approvedAt': FieldValue.serverTimestamp(),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Event approved and published!'),
            backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _reject(BuildContext context) async {
    await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .update({'status': 'rejected'});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Event rejected.'),
            backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = event['ticketPrice'];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.orange.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top: title + badges
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Chip(
                        label: event['category'] ?? 'General',
                        color: AppColors.primary),
                    const SizedBox(width: 6),
                    _Chip(
                        label: event['type'] ?? 'In Person',
                        color: const Color(0xFF57A683)),
                    const Spacer(),
                    _Chip(
                        label: 'PENDING',
                        color: Colors.orange),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  event['title'] ?? 'Untitled Event',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(
                color: AppColors.dividerLight, height: 1),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _DetailRow(Icons.business_outlined, 'Organizer',
                    event['organizerName'] ?? 'Unknown'),
                const SizedBox(height: 8),
                _DetailRow(Icons.location_on_outlined, 'Location',
                    event['location'] ?? 'Not specified'),
                const SizedBox(height: 8),
                _DetailRow(Icons.place_outlined, 'Venue',
                    event['venue']?.toString().isNotEmpty == true
                        ? event['venue']
                        : 'Not specified'),
                const SizedBox(height: 8),
                _DetailRow(Icons.calendar_today_outlined,
                    'Start', event['startDate'] ?? '-'),
                const SizedBox(height: 8),
                _DetailRow(Icons.event_outlined, 'End',
                    event['endDate'] ?? '-'),
                const SizedBox(height: 8),
                _DetailRow(
                  Icons.confirmation_number_outlined,
                  'Price',
                  price == null
                      ? 'Not specified'
                      : price == 0
                          ? 'Free'
                          : 'RM $price',
                ),
                if (event['description'] != null &&
                    event['description'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _DetailRow(Icons.description_outlined,
                      'Description', event['description']),
                ],
                if (event['keywords'] != null &&
                    (event['keywords'] as List).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.label_outline,
                          size: 15, color: AppColors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children:
                              (event['keywords'] as List)
                                  .map((k) => Container(
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 8,
                                            vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors
                                              .primarySurface,
                                          borderRadius:
                                              BorderRadius.circular(
                                                  6),
                                        ),
                                        child: Text(k.toString(),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors
                                                    .primary)),
                                      ))
                                  .toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child:
                Divider(color: AppColors.dividerLight, height: 1),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reject(context),
                    icon: const Icon(Icons.close_rounded,
                        size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side:
                          const BorderSide(color: AppColors.error),
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approve(context),
                    icon: const Icon(Icons.check_rounded,
                        size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ORGANIZERS PAGE
// ─────────────────────────────────────────────

class _OrganizersPage extends StatefulWidget {
  const _OrganizersPage();

  @override
  State<_OrganizersPage> createState() => _OrganizersPageState();
}

class _OrganizersPageState extends State<_OrganizersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 28, 20, 16),
            child: Text(
              'Organizers',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(4),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.grey,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              dividerColor: Colors.transparent,
              padding: EdgeInsets.zero,
              tabs: const [
                Tab(text: 'Pending'),
                Tab(text: 'All Companies'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _PendingOrganizersTab(),
                _AllOrganizersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingOrganizersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('organizers')
          .where('isVerified', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary));
        }
        final orgs = snapshot.data?.docs ?? [];
        if (orgs.isEmpty) {
          return const _EmptyState(
            icon: Icons.verified_rounded,
            message: 'No pending organizers!',
            subtitle: 'All verified ✓',
            iconColor: AppColors.success,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: orgs.length,
          itemBuilder: (context, i) {
            final org = orgs[i].data() as Map<String, dynamic>;
            final orgId = orgs[i].id;
            return _OrganizerCard(org: org, orgId: orgId);
          },
        );
      },
    );
  }
}

class _AllOrganizersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('organizers')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary));
        }
        final orgs = snapshot.data?.docs ?? [];
        if (orgs.isEmpty) {
          return const _EmptyState(
            icon: Icons.business_rounded,
            message: 'No companies yet',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: orgs.length,
          itemBuilder: (context, i) {
            final org = orgs[i].data() as Map<String, dynamic>;
            final orgId = orgs[i].id;
            return _OrganizerCard(
                org: org, orgId: orgId, showAll: true);
          },
        );
      },
    );
  }
}

class _OrganizerCard extends StatelessWidget {
  final Map<String, dynamic> org;
  final String orgId;
  final bool showAll;

  const _OrganizerCard(
      {required this.org,
      required this.orgId,
      this.showAll = false});

  Future<void> _verify(BuildContext context) async {
    await FirebaseFirestore.instance
        .collection('organizers')
        .doc(orgId)
        .update({'isVerified': true, 'status': 'verified'});
    final uid = org['uid'];
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'isVerified': true});
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Organizer verified!'),
            backgroundColor: AppColors.primary),
      );
    }
  }

  Future<void> _reject(BuildContext context) async {
    await FirebaseFirestore.instance
        .collection('organizers')
        .doc(orgId)
        .update({'isVerified': false, 'status': 'rejected'});
    final uid = org['uid'];
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'organizerStatus': 'rejected'});
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Organizer rejected.'),
            backgroundColor: AppColors.error),
      );
    }
  }

  void _showIc(BuildContext context) {
    final icUrl = org['icUrl'].toString();
    final imageWidget = icUrl.startsWith('data:image')
        ? Image.memory(base64Decode(icUrl.split(',')[1]),
            fit: BoxFit.contain)
        : Image.network(icUrl, fit: BoxFit.contain);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card)),
        backgroundColor: const Color(0xFF1A1A1A),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: AppSpacing.cardPadding,
              child: Row(
                children: [
                  const Text('IC / Document',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close,
                          color: AppColors.grey),
                      onPressed: () =>
                          Navigator.pop(context)),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16)),
              child: imageWidget,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = org['isVerified'] ?? false;
    final status = org['status'] ?? 'pending';

    Color statusColor;
    Color statusBg;
    IconData statusIcon;
    String statusText;

    if (isVerified) {
      statusColor = AppColors.success;
      statusBg = AppColors.successSurface;
      statusIcon = Icons.verified_rounded;
      statusText = 'Verified';
    } else if (status == 'rejected') {
      statusColor = AppColors.error;
      statusBg = AppColors.errorSurface;
      statusIcon = Icons.cancel_outlined;
      statusText = 'Rejected';
    } else {
      statusColor = Colors.orange;
      statusBg = AppColors.warningSurface;
      statusIcon = Icons.hourglass_empty_rounded;
      statusText = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVerified
              ? AppColors.success.withOpacity(0.3)
              : AppColors.divider,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.business_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        org['companyName'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon,
                                size: 10, color: statusColor),
                            const SizedBox(width: 4),
                            Text(statusText,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: statusColor,
                                    fontWeight:
                                        FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(
                  color: AppColors.dividerLight, height: 1),
            ),

            _DetailRow(
                Icons.email_outlined, 'Email',
                org['email'] ?? 'Not provided'),
            const SizedBox(height: 8),
            _DetailRow(
                Icons.phone_outlined, 'Phone',
                org['phone'] ?? 'Not provided'),
            if (org['description'] != null) ...[
              const SizedBox(height: 8),
              _DetailRow(Icons.info_outlined, 'About',
                  org['description']),
            ],
            if (org['submittedAt'] != null) ...[
              const SizedBox(height: 8),
              _DetailRow(Icons.schedule_outlined, 'Submitted',
                  () {
                try {
                  final dt =
                      (org['submittedAt'] as dynamic).toDate()
                          as DateTime;
                  return '${dt.day}/${dt.month}/${dt.year}';
                } catch (_) {
                  return 'Unknown';
                }
              }()),
            ],

            if (org['icUrl'] != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showIc(context),
                  icon: const Icon(Icons.badge_outlined,
                      size: 16),
                  label: const Text('View IC / Document'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(
                        color: AppColors.primary),
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],

            // Action buttons
            if (!isVerified && status != 'rejected') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _reject(context),
                      icon: const Icon(Icons.close_rounded,
                          size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(
                            color: AppColors.error),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _verify(context),
                      icon: const Icon(Icons.verified_rounded,
                          size: 16),
                      label: const Text('Verify'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (isVerified) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _reject(context),
                  icon: const Icon(
                      Icons.remove_circle_outline_rounded,
                      size: 16),
                  label: const Text('Revoke Verification'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side:
                        const BorderSide(color: AppColors.error),
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SHARED SMALL WIDGETS
// ─────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.grey),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.grey)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;
  final Color? iconColor;

  const _EmptyState(
      {required this.icon,
      required this.message,
      this.subtitle,
      this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 60, color: iconColor ?? AppColors.grey600),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                style: const TextStyle(color: AppColors.grey)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ADMIN QUICK ACTION CARD
// ─────────────────────────────────────────────

class _AdminQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminQuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.grey),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  MANAGE EVENT IMAGES SCREEN
// ─────────────────────────────────────────────

class ManageEventImagesScreen extends StatefulWidget {
  const ManageEventImagesScreen({super.key});

  @override
  State<ManageEventImagesScreen> createState() =>
      _ManageEventImagesScreenState();
}

class _ManageEventImagesScreenState extends State<ManageEventImagesScreen> {
  final Set<String> _uploading = <String>{};
  String _search = '';

  Future<void> _pickAndUpdateImage(String eventId) async {
    if (_uploading.contains(eventId)) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _uploading.add(eventId));

    try {
      final bytes = await File(picked.path).readAsBytes();
      // Compress for Firestore (keep well under 1MB doc limit)
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 800,
        minHeight: 450,
        quality: 70,
        format: CompressFormat.jpeg,
      );

      final imageUrl =
          'data:image/jpeg;base64,${base64Encode(compressed)}';

      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .update({'imageUrl': imageUrl});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event image updated!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading.remove(eventId));
    }
  }

  Future<void> _clearImage(String eventId) async {
    await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .update({'imageUrl': ''});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image removed.'),
          backgroundColor: AppColors.grey,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Manage Event Images',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: TextField(
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search events…',
                  hintStyle: const TextStyle(color: AppColors.grey),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.grey),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('events')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary));
                  }
                  var docs = snapshot.data?.docs ?? [];
                  if (_search.isNotEmpty) {
                    docs = docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final title =
                          (data['title'] ?? '').toString().toLowerCase();
                      return title.contains(_search);
                    }).toList();
                  }
                  if (docs.isEmpty) {
                    return const _EmptyState(
                      icon: Icons.festival_rounded,
                      message: 'No events found',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final eventId = docs[i].id;
                      final event =
                          docs[i].data() as Map<String, dynamic>;
                      return _ManageEventImageRow(
                        eventId: eventId,
                        event: event,
                        isUploading: _uploading.contains(eventId),
                        onEditImage: () => _pickAndUpdateImage(eventId),
                        onClearImage: () => _clearImage(eventId),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageEventImageRow extends StatelessWidget {
  final String eventId;
  final Map<String, dynamic> event;
  final bool isUploading;
  final VoidCallback onEditImage;
  final VoidCallback onClearImage;

  const _ManageEventImageRow({
    required this.eventId,
    required this.event,
    required this.isUploading,
    required this.onEditImage,
    required this.onClearImage,
  });

  Widget _buildPreview() {
    final raw = (event['imageUrl'] ?? '').toString();
    if (raw.isEmpty) return _placeholder();

    if (raw.startsWith('data:image')) {
      try {
        final base64Str =
            raw.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder());
      } catch (_) {
        return _placeholder();
      }
    }
    return Image.network(raw,
        fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder());
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.primary.withOpacity(0.12),
      child: const Center(
        child: Icon(Icons.festival_rounded,
            color: AppColors.primary, size: 32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (event['title'] ?? 'Untitled').toString();
    final status = (event['status'] ?? 'pending').toString();
    final hasImage = (event['imageUrl'] ?? '').toString().isNotEmpty;

    Color statusColor;
    if (status == 'published') {
      statusColor = AppColors.success;
    } else if (status == 'rejected') {
      statusColor = AppColors.error;
    } else {
      statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image preview
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildPreview(),
                  if (isUploading)
                    Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Info + actions
          Padding(
            padding: const EdgeInsets.all(14),
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
                        style: const TextStyle(
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
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  event['organizerName']?.toString() ?? '',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isUploading ? null : onEditImage,
                        icon: const Icon(Icons.camera_alt_rounded,
                            size: 16),
                        label: Text(hasImage
                            ? 'Replace Image'
                            : 'Upload Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    if (hasImage) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: isUploading ? null : onClearImage,
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 16),
                        label: const Text('Clear'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}