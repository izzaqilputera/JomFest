import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:qr_flutter/qr_flutter.dart';
import 'event_detail_screen.dart';
import 'recommendation_service.dart';
import 'theme.dart';
import 'account_screens.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;
  /// Bumped when switching to For You so recommendations refetch (IndexedStack
  /// keeps the tab alive, so initState alone would never see new purchases).
  int _forYouReloadKey = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: IndexedStack(
        index: _currentNavIndex,
        children: [
          const _DiscoverPage(),
          _ForYouPage(reloadKey: _forYouReloadKey),
          const _TicketsPage(),
          const _AccountPage(),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: (i) {
          setState(() {
            final prev = _currentNavIndex;
            _currentNavIndex = i;
            if (i == 1 && prev != 1) _forYouReloadKey++;
          });
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  BOTTOM NAV BAR
// ─────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItem(icon: Icons.home_rounded, label: 'Home'),
      _NavItem(icon: Icons.stars_rounded, label: 'For You'),
      _NavItem(icon: Icons.confirmation_number_outlined, label: 'Tickets'),
      _NavItem(icon: Icons.person_outline_rounded, label: 'Account'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 1),
        ),
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
                      Icon(
                        items[i].icon,
                        size: 24,
                        color: selected
                            ? AppColors.primary
                            : AppColors.grey600,
                      ),
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

// ─────────────────────────────────────────────
//  DISCOVER PAGE  (main home)
// ─────────────────────────────────────────────

class _DiscoverPage extends StatefulWidget {
  const _DiscoverPage();

  @override
  State<_DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<_DiscoverPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _userName = '';
  String _userLocation = 'Malaysia';
  String _userPhotoUrl = '';
  StreamSubscription<DocumentSnapshot>? _userSub;

  final List<String> _categories = [
    'All', 'Music', 'Food & Drink', 'Arts & Culture',
    'Sports', 'Technology', 'Family',
    'Health & Wellness', 'Business', 'Comedy', 'Education',
  ];

  @override
  void initState() {
    super.initState();
    _subscribeToUserDoc();
  }

  void _subscribeToUserDoc() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final data = snap.data() ?? {};
      setState(() {
        _userName = data['name'] ?? 'there';
        _userLocation = data['location'] ?? 'Malaysia';
        _userPhotoUrl = data['photoUrl'] ?? '';
      });
    });
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Header ──────────────────────────────
        SliverToBoxAdapter(child: _buildHeader()),

        // ── Search bar ──────────────────────────
        SliverToBoxAdapter(child: _buildSearchBar()),

        // ── Category chips ──────────────────────
        SliverToBoxAdapter(child: _buildCategoryChips()),

        // ── Featured section ────────────────────
        SliverToBoxAdapter(
          child: _SectionHeader(title: 'Featured', onTap: () {}),
        ),
        SliverToBoxAdapter(child: _buildFeaturedRow()),

        // ── All Events ──────────────────────────
        SliverToBoxAdapter(
          child: _SectionHeader(title: 'All Events', onTap: () {}),
        ),
        _buildAllEventsList(),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  // ── Header ────────────────────────────────────
  Widget _buildHeaderAvatar() {
    if (_userPhotoUrl.isNotEmpty) {
      try {
        final base64String =
            _userPhotoUrl.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
        final bytes = base64Decode(base64String);
        return Image.memory(bytes,
            fit: BoxFit.cover, width: 42, height: 42,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.person_rounded, color: AppColors.primary, size: 22));
      } catch (_) {}
    }
    return const Icon(Icons.person_rounded, color: AppColors.primary, size: 22);
  }

  Widget _buildHeader() {
    final firstName = _userName.isNotEmpty
        ? _userName.split(' ').first
        : 'there';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
      color: AppColors.scaffoldBg,
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.2),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.4), width: 1.5),
            ),
            child: ClipOval(
              child: _buildHeaderAvatar(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $firstName',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 12, color: AppColors.grey),
                    const SizedBox(width: 3),
                    Text(
                      _userLocation,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar ────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: TextField(
        controller: _searchController,
        onChanged: (val) =>
            setState(() => _searchQuery = val.toLowerCase()),
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search events...',
          hintStyle:
              const TextStyle(color: AppColors.grey, fontSize: 14),
          prefixIcon:
              const Icon(Icons.search_rounded, color: AppColors.grey, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: const Icon(Icons.close,
                      color: AppColors.grey, size: 18),
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: AppColors.divider, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ── Category chips ────────────────────────────
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final cat = _categories[i];
          final selected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : AppColors.divider,
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color:
                      selected ? AppColors.white : AppColors.grey,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Featured horizontal scroll ─────────────────
  Widget _buildFeaturedRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('status', isEqualTo: 'published')
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SizedBox(
              height: 220,
              child: Center(
                  child: Text('Failed to load events: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red))));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 220,
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary)));
        }
        final events = snapshot.data?.docs ?? [];
        if (events.isEmpty) {
          return const SizedBox(
              height: 220,
              child: Center(
                  child: Text('No published events found.',
                      style: TextStyle(color: AppColors.grey))));
        }
        return SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: events.length,
            itemBuilder: (context, i) {
              final event =
                  events[i].data() as Map<String, dynamic>;
              final eventId = events[i].id;
              return _FeaturedCard(
                event: event,
                eventId: eventId,
              );
            },
          ),
        );
      },
    );
  }

  // ── All events vertical list ────────────────────
  Widget _buildAllEventsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('status', isEqualTo: 'published')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Failed to load events: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(
                child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(
                  color: AppColors.primary),
            )),
          );
        }

        var events = snapshot.data?.docs ?? [];

        if (_selectedCategory != 'All') {
          events = events
              .where((e) =>
                  (e.data() as Map<String, dynamic>)['category'] ==
                  _selectedCategory)
              .toList();
        }

        if (_searchQuery.isNotEmpty) {
          events = events.where((e) {
            final data = e.data() as Map<String, dynamic>;
            return data['title']
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery) ||
                data['location']
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery);
          }).toList();
        }

        if (events.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.search_off,
                      size: 52, color: AppColors.grey600),
                  const SizedBox(height: 12),
                  const Text('No events found',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text('Try a different category or search',
                      style: TextStyle(color: AppColors.grey)),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final event =
                  events[index].data() as Map<String, dynamic>;
              final eventId = events[index].id;
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 6),
                child: _EventListCard(
                    event: event, eventId: eventId),
              );
            },
            childCount: events.length,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  FOR YOU PAGE  (recommendations tab)
// ─────────────────────────────────────────────

class _ForYouPage extends StatefulWidget {
  final int reloadKey;

  const _ForYouPage({this.reloadKey = 0});

  @override
  State<_ForYouPage> createState() => _ForYouPageState();
}

class _ForYouPageState extends State<_ForYouPage> {
  List<Map<String, dynamic>> _recommendations = [];
  bool _loadingRecs = true;

  @override
  void initState() {
    super.initState();
    _loadRecommendations(showFullScreenLoader: true);
  }

  @override
  void didUpdateWidget(covariant _ForYouPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reloadKey != oldWidget.reloadKey) {
      _loadRecommendations(showFullScreenLoader: false);
    }
  }

  Future<void> _loadRecommendations({bool showFullScreenLoader = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loadingRecs = false);
      return;
    }
    if (showFullScreenLoader && mounted) {
      setState(() => _loadingRecs = true);
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final interests =
        List<String>.from(userDoc.data()?['interests'] ?? []);
    final recs =
        await RecommendationService.getRecommendations(uid, interests);
    if (mounted) {
      setState(() {
        _recommendations = recs;
        _loadingRecs = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Text(
                'For You',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: _loadingRecs && _recommendations.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      backgroundColor: const Color(0xFF1A1A1A),
                      onRefresh: () =>
                          _loadRecommendations(showFullScreenLoader: false),
                      child: _recommendations.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              children: [
                                SizedBox(
                                    height: MediaQuery.sizeOf(context).height *
                                        0.22),
                                Icon(Icons.stars_rounded,
                                    size: 60, color: AppColors.grey600),
                                const SizedBox(height: 16),
                                const Text(
                                  'No recommendations yet',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'View, bookmark, or buy events to teach the '
                                  'engine your taste. You can also add interests '
                                  'in your profile. Pull down to refresh.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.grey),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              itemCount: _recommendations.length,
                              itemBuilder: (context, i) {
                                final event = _recommendations[i];
                                final eventId = event['eventId'] as String;
                                final score = (event['similarityScore']
                                        as double? ??
                                    0.0);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _ForYouListCard(
                                      event: event,
                                      eventId: eventId,
                                      score: score),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForYouListCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final String eventId;
  final double score;

  const _ForYouListCard(
      {required this.event, required this.eventId, required this.score});

  @override
  Widget build(BuildContext context) {
    final matchPercent = (score * 100).round();
    final price = event['ticketPrice'] ?? 0;
    final multiTier = ((event['ticketTiers'] as List?)?.length ?? 1) > 1;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(eventId: eventId, event: event),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14)),
              child: SizedBox(
                width: 90,
                height: 90,
                child: _EventImageWidget(
                  imageUrl: event['imageUrl'],
                  width: 90,
                  height: 90,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      event['title'] ?? 'Untitled',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.stars_rounded,
                                  size: 12, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                '$matchPercent% match',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            event['location'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.grey),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                price == 0 ? 'Free' : '${multiTier ? 'From ' : ''}RM$price',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: price == 0 ? AppColors.success : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SECTION HEADER
// ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _SectionHeader({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  FEATURED CARD  (tall, horizontal scroll)
// ─────────────────────────────────────────────

class _FeaturedCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final String eventId;

  const _FeaturedCard({required this.event, required this.eventId});

  @override
  Widget build(BuildContext context) {
    final category = event['category'] ?? 'General';
    final startDate = event['startDate'] ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              EventDetailScreen(eventId: eventId, event: event),
        ),
      ),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12, bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF1A1A1A),
        ),
        child: Stack(
          children: [
            // Background image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _EventImageWidget(
                imageUrl: event['imageUrl'],
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            // Dark gradient overlay bottom
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.75),
                    ],
                    stops: const [0.45, 1.0],
                  ),
                ),
              ),
            ),
            // Date badge (top right)
            if (startDate.isNotEmpty)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    startDate.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            // Bottom info
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event['title'] ?? 'Untitled',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  RECOMMENDED CARD  (shorter, horizontal scroll)
// ─────────────────────────────────────────────

class _RecommendedCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final String eventId;
  final double score;

  const _RecommendedCard(
      {required this.event,
      required this.eventId,
      required this.score});

  @override
  Widget build(BuildContext context) {
    final matchPercent = (score * 100).round();
    final price = event['ticketPrice'] ?? 0;
    final multiTier = ((event['ticketTiers'] as List?)?.length ?? 1) > 1;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              EventDetailScreen(eventId: eventId, event: event),
        ),
      ),
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 12, bottom: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.primary.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14)),
              child: SizedBox(
                height: 90,
                width: double.infinity,
                child: _EventImageWidget(
                    imageUrl: event['imageUrl'],
                    width: double.infinity,
                    height: 90),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.stars_rounded,
                                size: 10, color: AppColors.primary),
                            const SizedBox(width: 3),
                            Text(
                              '$matchPercent%',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        price == 0 ? 'Free' : '${multiTier ? 'From ' : ''}RM$price',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: price == 0
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    event['title'] ?? 'Untitled',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event['location'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  EVENT LIST CARD  (vertical all-events list)
// ─────────────────────────────────────────────

class _EventListCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final String eventId;

  const _EventListCard({required this.event, required this.eventId});

  @override
  Widget build(BuildContext context) {
    final price = event['ticketPrice'] ?? 0;
    final multiTier = ((event['ticketTiers'] as List?)?.length ?? 1) > 1;
    final category = event['category'] ?? 'General';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              EventDetailScreen(eventId: eventId, event: event),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 1),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14)),
              child: SizedBox(
                width: 90,
                height: 90,
                child: _EventImageWidget(
                  imageUrl: event['imageUrl'],
                  width: 90,
                  height: 90,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          price == 0 ? 'Free' : '${multiTier ? 'From ' : ''}RM $price',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: price == 0
                                ? AppColors.success
                                : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      event['title'] ?? 'Untitled',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: AppColors.grey),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            event['location'] ?? 'Unknown',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.grey),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 12, color: AppColors.grey),
                        const SizedBox(width: 3),
                        Text(
                          event['startDate'] ?? '',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SHARED IMAGE WIDGET
// ─────────────────────────────────────────────

class _EventImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;

  const _EventImageWidget(
      {this.imageUrl, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      if (imageUrl!.startsWith('data:image')) {
        try {
          final base64String = imageUrl!
              .replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
          final bytes = base64Decode(base64String);
          return Image.memory(bytes,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder());
        } catch (_) {
          return _placeholder();
        }
      } else {
        return Image.network(imageUrl!,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder());
      }
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.primary.withOpacity(0.12),
      child: const Center(
        child: Icon(Icons.festival_rounded,
            color: AppColors.primary, size: 30),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  TICKETS PAGE
// ─────────────────────────────────────────────

class _TicketsPage extends StatelessWidget {
  final bool showBack;
  const _TicketsPage({this.showBack = false});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: showBack
          ? AppBar(
              backgroundColor: AppColors.scaffoldBg,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              title: const Text(
                'My Tickets',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            if (!showBack)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Text(
                  'My Tickets',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            // Tickets list
            Expanded(
              child: uid == null
                  ? const Center(
                      child: Text('Please log in to view tickets',
                          style:
                              TextStyle(color: AppColors.grey)))
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('tickets')
                          .where('userId', isEqualTo: uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.primary));
                        }

                        final tickets =
                            snapshot.data?.docs ?? [];

                        if (tickets.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons
                                      .confirmation_number_outlined,
                                  size: 64,
                                  color: AppColors.grey600,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No tickets yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Your purchased tickets will appear here',
                                  style: TextStyle(
                                      color: AppColors.grey),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20),
                          itemCount: tickets.length,
                          itemBuilder: (context, i) {
                            final ticket = tickets[i].data()
                                as Map<String, dynamic>;
                            return _TicketCard(
                                ticket: ticket);
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

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final status = ticket['status'] ?? 'confirmed';
    final statusColor = status == 'confirmed'
        ? AppColors.success
        : status == 'pending'
            ? Colors.orange
            : AppColors.grey;
    final qrData = (ticket['qrData'] as String?)?.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // Top section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.festival_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket['eventTitle'] ?? 'Event',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        ticket['eventDate'] ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
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
          ),
          // Divider with circles
          Row(
            children: [
              const _CircleCut(alignment: Alignment.centerLeft),
              Expanded(
                child: DashedDivider(),
              ),
              const _CircleCut(alignment: Alignment.centerRight),
            ],
          ),
          // Bottom section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _TicketInfo(
                    label: 'Ticket ID',
                    value: ticket['ticketId'] ?? '-'),
                _TicketInfo(
                    label: 'Qty',
                    value:
                        '${ticket['quantity'] ?? 1} pax'),
                _TicketInfo(
                    label: 'Amount',
                    value: ticket['amount'] != null
                        ? 'RM ${ticket['amount']}'
                        : 'Free'),
              ],
            ),
          ),
          if (qrData != null && qrData.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'QR Code',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: QrImageView(
                                data: qrData,
                                size: 120,
                                backgroundColor: AppColors.white,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TicketInfo extends StatelessWidget {
  final String label;
  final String value;
  const _TicketInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: AppColors.grey)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ],
    );
  }
}

class _CircleCut extends StatelessWidget {
  final Alignment alignment;
  const _CircleCut({required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.divider),
      ),
    );
  }
}

class DashedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 6.0;
        const dashSpace = 4.0;
        final totalWidth = constraints.maxWidth;
        final count =
            (totalWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(count, (_) {
            return Container(
              width: dashWidth,
              height: 1,
              color: AppColors.divider,
            );
          }),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  ACCOUNT PAGE
// ─────────────────────────────────────────────

class _AccountPage extends StatefulWidget {
  const _AccountPage();

  @override
  State<_AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<_AccountPage> {
  Map<String, dynamic>? _userData;
  bool _loading = true;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (mounted) {
      setState(() {
        _userData = doc.data();
        _loading = false;
      });
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    if (mounted) setState(() => _uploadingPhoto = true);

    try {
      final bytes = await File(picked.path).readAsBytes();

      // Compress to a small size so the base64 string fits within
      // Firestore's 1 MB per-document limit.
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 256,
        minHeight: 256,
        quality: 60,
        format: CompressFormat.jpeg,
      );

      final base64Str =
          'data:image/jpeg;base64,${base64Encode(compressed)}';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'photoUrl': base64Str});

      if (mounted) {
        setState(() {
          _userData = {
            ...?_userData,
            'photoUrl': base64Str,
          };
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Widget _buildAvatar() {
    final photoUrl = _userData?['photoUrl'] as String?;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      try {
        final base64String =
            photoUrl.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
        final bytes = base64Decode(base64String);
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: ClipOval(
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: 80,
              height: 80,
              errorBuilder: (_, __, ___) => _defaultAvatar(),
            ),
          ),
        );
      } catch (_) {
        return _defaultAvatar();
      }
    }
    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withOpacity(0.15),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: const Icon(Icons.person_rounded, size: 40, color: AppColors.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    // Avatar with edit button
                    GestureDetector(
                      onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          _buildAvatar(),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.scaffoldBg, width: 2),
                            ),
                            child: _uploadingPhoto
                                ? const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.white,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt_rounded,
                                    size: 14, color: AppColors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _userData?['name'] ?? 'User',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      FirebaseAuth.instance.currentUser?.email ?? '',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.grey),
                    ),
                    const SizedBox(height: 8),
                    // Location chip
                    if (_userData?['location'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 12, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              _userData!['location'],
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 28),
                    // Interests
                    if (_userData?['interests'] != null &&
                        (_userData!['interests'] as List).isNotEmpty) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Interests',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (_userData!['interests'] as List)
                            .map((interest) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySurface,
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                        color: AppColors.primary
                                            .withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    interest.toString(),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primary),
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 28),
                    ],
                    // Menu items
                    _AccountMenuItem(
                      icon: Icons.confirmation_number_outlined,
                      label: 'My Tickets',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const _TicketsPage(showBack: true),
                          ),
                        );
                      },
                    ),
                    _AccountMenuItem(
                      icon: Icons.favorite_outline_rounded,
                      label: 'Saved Events',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SavedEventsScreen(),
                          ),
                        );
                      },
                    ),
                    _AccountMenuItem(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        );
                      },
                    ),
                    _AccountMenuItem(
                      icon: Icons.help_outline_rounded,
                      label: 'Help & Support',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HelpSupportScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // Sign out
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                        },
                        icon: const Icon(Icons.logout_rounded,
                            size: 18),
                        label: const Text('Sign Out'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(
                              color: AppColors.error),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.lg),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }
}

class _AccountMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AccountMenuItem(
      {required this.icon,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.grey),
          ],
        ),
      ),
    );
  }
}