import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _parseDate(String? s) {
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

class RecommendationService {
  static const List<String> categories = [
    'Music', 'Food & Drink', 'Arts & Culture', 'Sports',
    'Technology', 'Family', 'Health & Wellness',
    'Business', 'Comedy', 'Education',
  ];

  static const List<String> types = [
    'In Person', 'Virtual', 'Hybrid'
  ];

  static const Map<String, double> weights = {
    'view': 0.3,
    'bookmark': 0.8,
    'search_click': 0.5,
    'purchase': 3.0, // purchase is the strongest intent signal
  };

  /// Build a 17-dim vector from category + type strings alone.
  /// Used as a fallback when an event or interaction has no stored featureVector.
  static List<double> _vectorFromFields({
    String? category,
    String? type,
    double? price,
  }) {
    final v = List<double>.filled(17, 0.0);
    final catIdx = categories.indexOf(category ?? '');
    if (catIdx >= 0) v[catIdx] = 1.0;
    final typeIdx = types.indexOf(type ?? '');
    if (typeIdx >= 0) v[10 + typeIdx] = 1.0;
    if (price != null) {
      if (price == 0) {
        v[13] = 1.0;
      } else if (price <= 50) {
        v[14] = 1.0;
      } else if (price <= 100) {
        v[15] = 1.0;
      } else {
        v[16] = 1.0;
      }
    }
    return v;
  }

  /// Return a valid 17-dim vector for an event doc, synthesising from
  /// category/type if the stored featureVector is absent or malformed.
  static List<double> _eventVector(Map<String, dynamic> event) {
    final stored = event['featureVector'] as List<dynamic>?;
    if (stored != null && stored.length == 17) {
      return stored.map((v) => (v as num).toDouble()).toList();
    }
    return _vectorFromFields(
      category: event['category'] as String?,
      type: event['type'] as String?,
      price: (event['ticketPrice'] as num?)?.toDouble(),
    );
  }

  /// Build a user taste vector from their explicit interests + implicit
  /// interactions. If an interaction has no stored featureVector (e.g. from
  /// seed events), we synthesise one from its category field so the
  /// interaction is never silently ignored.
  static List<double> buildUserVector(
    List<String> interests,
    List<Map<String, dynamic>> interactions,
  ) {
    final vector = List<double>.filled(17, 0.0);

    // Explicit profile interests (weight 1.0 each)
    for (final interest in interests) {
      final idx = categories.indexOf(interest);
      if (idx >= 0) vector[idx] += 1.0;
    }

    // Implicit signals from events the user engaged with
    for (final interaction in interactions) {
      final type = interaction['type'] as String? ?? 'view';
      final weight = weights[type] ?? 0.3;

      List<double> fv;
      final stored = interaction['featureVector'] as List<dynamic>?;
      if (stored != null && stored.length == 17) {
        fv = stored.map((v) => (v as num).toDouble()).toList();
      } else {
        // Fallback: synthesise from category so interaction is never lost
        fv = _vectorFromFields(
          category: interaction['category'] as String?,
          type: interaction['eventType'] as String?,
        );
      }

      for (int i = 0; i < 17; i++) {
        vector[i] += fv[i] * weight;
      }

    }

    return _normalizeVector(vector);
  }

  static List<double> _normalizeVector(List<double> vec) {
    double sumSq = 0.0;
    for (final v in vec) { sumSq += v * v; }
    if (sumSq == 0.0) return vec;
    final mag = _sqrt(sumSq);
    return vec.map((v) => v / mag).toList();
  }

  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double z = x;
    for (int i = 0; i < 100; i++) {
      z = z - (z * z - x) / (2 * z);
    }
    return z;
  }

  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0;
    double dot = 0, magA = 0, magB = 0;
    for (int i = 0; i < a.length; i++) {
      dot  += a[i] * b[i];
      magA += a[i] * a[i];
      magB += b[i] * b[i];
    }
    if (magA == 0 || magB == 0) return 0;
    return dot / (_sqrt(magA) * _sqrt(magB));
  }

  static Future<List<Map<String, dynamic>>> getRecommendations(
    String uid,
    List<String> interests,
  ) async {
    try {
      // 1. Fetch all interactions for this user
      final interactionsSnap = await FirebaseFirestore.instance
          .collection('interactions')
          .where('uid', isEqualTo: uid)
          .get();
      final interactions =
          interactionsSnap.docs.map((d) => d.data()).toList();

      // 2. Collect eventIds the user already purchased (exclude from results)
      final purchasedIds = interactions
          .where((i) => i['type'] == 'purchase')
          .map((i) => i['eventId'] as String?)
          .whereType<String>()
          .toSet();

      // 3. Build user taste vector
      final userVector = buildUserVector(interests, interactions);

      // 4. If we have no signal at all, return empty early
      final hasSignal = userVector.any((v) => v > 0);
      if (!hasSignal) return [];

      // 5. Fetch all published events
      final eventsSnap = await FirebaseFirestore.instance
          .collection('events')
          .where('status', isEqualTo: 'published')
          .get();

      // 6. Score every event (skip purchased and past events)
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final scored = <Map<String, dynamic>>[];
      for (final doc in eventsSnap.docs) {
        final eventId = doc.id;
        if (purchasedIds.contains(eventId)) continue;

        final event = doc.data();

        // Skip events that have already passed
        final eventDate = _parseDate(event['startDate']?.toString());
        if (eventDate != null && eventDate.isBefore(todayStart)) continue;

        final eventVec = _eventVector(event);
        final score = cosineSimilarity(userVector, eventVec);

        if (score > 0.05) {
          scored.add({
            ...event,
            'eventId': eventId,
            'similarityScore': score,
          });
        }
      }

      // 7. Sort by score, return top 10
      scored.sort((a, b) => (b['similarityScore'] as double)
          .compareTo(a['similarityScore'] as double));
      return scored.take(10).toList();
    } catch (e) {
      return [];
    }
  }
}
