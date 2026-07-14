import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'theme.dart';

// ─────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────

class _Analytics {
  final int totalTickets;
  final double totalRevenue;
  final int totalEvents;
  final List<BarChartGroupData> weekGroups;
  final List<String> weekLabels;
  final List<MapEntry<String, double>> revenueByEvent;
  final List<MapEntry<String, int>> byCategory;
  final double maxEventRevenue;

  const _Analytics({
    required this.totalTickets,
    required this.totalRevenue,
    required this.totalEvents,
    required this.weekGroups,
    required this.weekLabels,
    required this.revenueByEvent,
    required this.byCategory,
    required this.maxEventRevenue,
  });
}

// ─────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────

class OrganizerAnalyticsScreen extends StatefulWidget {
  final String organizerUid;
  const OrganizerAnalyticsScreen({super.key, required this.organizerUid});

  @override
  State<OrganizerAnalyticsScreen> createState() =>
      _OrganizerAnalyticsScreenState();
}

class _OrganizerAnalyticsScreenState
    extends State<OrganizerAnalyticsScreen> {
  bool _loading = true;
  String? _error;
  _Analytics? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 1. Organizer's events
      final eventsSnap = await FirebaseFirestore.instance
          .collection('events')
          .where('organizerUid', isEqualTo: widget.organizerUid)
          .get();

      final eventIds = eventsSnap.docs.map((d) => d.id).toList();
      final categoryMap = <String, String>{
        for (final d in eventsSnap.docs)
          d.id: (d.data()['category'] as String?) ?? 'General',
      };

      // 2. Confirmed tickets for those events (Firestore whereIn ≤ 30)
      final tickets = <Map<String, dynamic>>[];
      for (var i = 0; i < eventIds.length; i += 30) {
        final batch =
            eventIds.sublist(i, math.min(i + 30, eventIds.length));
        final snap = await FirebaseFirestore.instance
            .collection('tickets')
            .where('eventId', whereIn: batch)
            .where('status', isEqualTo: 'confirmed')
            .get();
        for (final d in snap.docs) {
          tickets.add(d.data());
        }
      }

      if (mounted) {
        setState(() {
          _data = _process(tickets, eventsSnap.docs.length, categoryMap);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  _Analytics _process(
    List<Map<String, dynamic>> tickets,
    int totalEvents,
    Map<String, String> categoryMap,
  ) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // Daily buckets: index 0 = 6 days ago, index 6 = today
    final dayCounts = List<int>.filled(7, 0);
    final revByEvent = <String, double>{};
    final byCategory = <String, int>{};
    double totalRevenue = 0;

    for (final t in tickets) {
      final ts = (t['purchasedAt'] as Timestamp?)?.toDate();
      if (ts != null) {
        final dayStart = DateTime(ts.year, ts.month, ts.day);
        final daysAgo = todayStart.difference(dayStart).inDays;
        if (daysAgo >= 0 && daysAgo < 7) {
          dayCounts[6 - daysAgo]++;
        }
      }

      final amt = (t['amount'] as num?)?.toDouble() ?? 0;
      totalRevenue += amt;

      final title = (t['eventTitle'] as String?) ?? 'Unknown';
      revByEvent[title] = (revByEvent[title] ?? 0) + amt;

      final cat = categoryMap[t['eventId'] as String?] ?? 'General';
      byCategory[cat] = (byCategory[cat] ?? 0) + 1;
    }

    final weekGroups = List.generate(7, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: dayCounts[i].toDouble(),
            color: AppColors.primary,
            width: 16,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });

    final weekLabels = List.generate(7, (i) {
      final d = todayStart.subtract(Duration(days: 6 - i));
      return '${d.day}/${d.month}';
    });

    final sortedRevByEvent = revByEvent.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sortedByCategory = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _Analytics(
      totalTickets: tickets.length,
      totalRevenue: totalRevenue,
      totalEvents: totalEvents,
      weekGroups: weekGroups,
      weekLabels: weekLabels,
      revenueByEvent: sortedRevByEvent,
      byCategory: sortedByCategory,
      maxEventRevenue:
          sortedRevByEvent.isEmpty ? 1 : sortedRevByEvent.first.value,
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          'Analytics',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _Body(data: _data!),
    );
  }
}

// ─────────────────────────────────────────────
//  BODY
// ─────────────────────────────────────────────

class _Body extends StatelessWidget {
  final _Analytics data;
  const _Body({required this.data});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    if (data.totalTickets == 0) {
      return _EmptyState(totalEvents: data.totalEvents);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        const SizedBox(height: 8),
        _SummaryRow(data: data),
        const SizedBox(height: 20),
        _ChartCard(
          title: 'Ticket Sales — Last 7 Days',
          child: _SalesBarChart(data: data),
        ),
        const SizedBox(height: 16),
        if (data.revenueByEvent.isNotEmpty) ...[
          _ChartCard(
            title: 'Revenue by Event',
            child: _RevenueByEventBars(data: data),
          ),
          const SizedBox(height: 16),
        ],
        if (data.byCategory.isNotEmpty)
          _ChartCard(
            title: 'Attendance by Category',
            child: _CategoryDonut(data: data),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  SUMMARY ROW
// ─────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final _Analytics data;
  const _SummaryRow({required this.data});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Row(
      children: [
        _StatCard(
          icon: Icons.payments_outlined,
          label: 'Revenue',
          value: 'RM ${data.totalRevenue.toStringAsFixed(0)}',
          color: AppColors.primary,
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.confirmation_number_outlined,
          label: 'Tickets',
          value: '${data.totalTickets}',
          color: const Color(0xFF6366F1),
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.festival_rounded,
          label: 'Events',
          value: '${data.totalEvents}',
          color: const Color(0xFFEC4899),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11, color: AppColors.grey)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CHART CARD WRAPPER
// ─────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  BAR CHART — 7-day ticket sales
// ─────────────────────────────────────────────

class _SalesBarChart extends StatelessWidget {
  final _Analytics data;
  const _SalesBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final maxY = data.weekGroups
        .expand((g) => g.barRods)
        .map((r) => r.toY)
        .fold(0.0, (a, b) => a > b ? a : b);
    final effectiveMax = math.max(maxY * 1.3, 4.0);
    final interval = math.max(1.0, (effectiveMax / 4).ceilToDouble());

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: effectiveMax,
          barGroups: data.weekGroups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.divider,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: interval,
                getTitlesWidget: (v, meta) {
                  if (v == meta.max) return const SizedBox();
                  return Text(
                    '${v.toInt()}',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.grey),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= data.weekLabels.length) {
                    return const SizedBox();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      data.weekLabels[i],
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.grey),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${rod.toY.toInt()} sold',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  REVENUE BY EVENT — horizontal progress bars
// ─────────────────────────────────────────────

class _RevenueByEventBars extends StatelessWidget {
  final _Analytics data;
  const _RevenueByEventBars({required this.data});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Column(
      children: data.revenueByEvent.map((entry) {
        final fraction = data.maxEventRevenue > 0
            ? (entry.value / data.maxEventRevenue).clamp(0.0, 1.0)
            : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'RM ${entry.value.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LayoutBuilder(builder: (context, constraints) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Stack(
                    children: [
                      Container(
                        height: 6,
                        width: constraints.maxWidth,
                        color: AppColors.divider,
                      ),
                      Container(
                        height: 6,
                        width: constraints.maxWidth * fraction,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────
//  DONUT CHART — attendance by category
// ─────────────────────────────────────────────

const _kPieColors = [
  Color(0xFF3B795E),
  Color(0xFF6366F1),
  Color(0xFFEC4899),
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFF3B82F6),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
];

class _CategoryDonut extends StatefulWidget {
  final _Analytics data;
  const _CategoryDonut({required this.data});

  @override
  State<_CategoryDonut> createState() => _CategoryDonutState();
}

class _CategoryDonutState extends State<_CategoryDonut> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final entries = widget.data.byCategory;
    final total = entries.fold<int>(0, (s, e) => s + e.value);

    final sections = List.generate(entries.length, (i) {
      final e = entries[i];
      final pct = total > 0 ? e.value / total * 100 : 0.0;
      final isTouched = i == _touched;
      return PieChartSectionData(
        value: e.value.toDouble(),
        title: isTouched ? '${pct.toStringAsFixed(1)}%' : '',
        color: _kPieColors[i % _kPieColors.length],
        radius: isTouched ? 62 : 52,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 44,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response == null ||
                        response.touchedSection == null) {
                      _touched = -1;
                    } else {
                      _touched =
                          response.touchedSection!.touchedSectionIndex;
                    }
                  });
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: List.generate(entries.length, (i) {
            final e = entries[i];
            final pct = total > 0 ? e.value / total * 100 : 0.0;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _kPieColors[i % _kPieColors.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '${e.key}  ${pct.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  EMPTY STATE
// ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final int totalEvents;
  const _EmptyState({required this.totalEvents});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 64, color: AppColors.grey600),
            const SizedBox(height: 16),
            Text(
              totalEvents == 0 ? 'No events yet' : 'No sales yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              totalEvents == 0
                  ? 'Create events to start tracking analytics'
                  : 'Charts appear once your events have confirmed bookings',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ERROR VIEW
// ─────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              'Failed to load analytics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: AppButtonStyles.primary,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
