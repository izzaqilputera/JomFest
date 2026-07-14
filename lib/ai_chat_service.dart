import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

/// A single chat message exchanged with the assistant.
class ChatMessage {
  final String role; // 'user' or 'model'
  final String text;
  ChatMessage({required this.role, required this.text});
}

/// Talks to the AI provider and answers customer questions about the
/// festivals/events stored in Firestore.
///
/// Provider: Google Gemini (generativelanguage API). To swap providers,
/// only [_sendToProvider] needs to change.
class AiChatService {
  // ── CONFIG ──────────────────────────────────────────────
  // 🔑 Paste your API key here.
  static const String _apiKey = 'AQ.Ab8RN6LOkyDGNJjHwfmQtWa5PktDaE36y_o_Y-mGp7aRadd_5Q';

  // gemini-2.5-flash returns 200 reliably on the free tier. (Avoid
  // gemini-2.0-flash / *-flash-latest: the former has a 0 free-tier limit
  // -> 429, the latter is frequently overloaded -> 503.)
  static const String _model = 'gemini-2.5-flash';
  static String get _endpoint =>
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent';

  /// Cached festival context so we don't re-query Firestore on every message.
  static String? _festivalContext;

  static bool get isConfigured =>
      _apiKey.isNotEmpty && _apiKey != 'PASTE_YOUR_API_KEY_HERE';

  /// Builds a compact text summary of all published events for the AI to
  /// ground its answers in. Cached after the first call.
  static Future<String> _loadFestivalContext() async {
    if (_festivalContext != null) return _festivalContext!;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('events')
          .where('status', isEqualTo: 'published')
          .get();

      if (snap.docs.isEmpty) {
        _festivalContext = 'There are currently no published festivals.';
        return _festivalContext!;
      }

      final buffer = StringBuffer();
      for (final doc in snap.docs) {
        final e = doc.data();
        buffer.writeln('• ${e['title'] ?? 'Untitled'}');
        if (e['category'] != null) buffer.writeln('  Category: ${e['category']}');
        if (e['startDate'] != null) {
          final end = e['endDate'];
          buffer.writeln(
              '  Date: ${e['startDate']}${end != null ? ' to $end' : ''}');
        }
        if (e['location'] != null) buffer.writeln('  Location: ${e['location']}');
        buffer.writeln('  Price: ${_priceLine(e)}');
        final desc = (e['description'] as String?)?.trim();
        if (desc != null && desc.isNotEmpty) {
          buffer.writeln(
              '  About: ${desc.length > 300 ? '${desc.substring(0, 300)}...' : desc}');
        }
        buffer.writeln();
      }
      _festivalContext = buffer.toString();
    } catch (e) {
      _festivalContext = 'Festival information is temporarily unavailable.';
    }
    return _festivalContext!;
  }

  static String _stripMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'\*\*'), '')   // bold **text**
        .replaceAll(RegExp(r'\*(?!\*)'), '') // italic *text*
        .replaceAll(RegExp(r'#{1,6} '), '')  // headers
        .replaceAll(RegExp(r'`'), '');        // inline code
  }

  static String _priceLine(Map<String, dynamic> e) {
    final tiers = e['ticketTiers'];
    if (tiers is List && tiers.isNotEmpty) {
      return tiers
          .whereType<Map>()
          .map((t) {
            final p = t['price'];
            final price = p is num ? p : num.tryParse('$p') ?? 0;
            return '${t['name'] ?? 'Standard'} RM$price';
          })
          .join(', ');
    }
    final p = e['ticketPrice'];
    final price = p is num ? p : num.tryParse('$p') ?? 0;
    return price == 0 ? 'Free' : 'RM$price';
  }

  /// Lets the app clear the cache (e.g. after new events are published).
  static void invalidateContext() => _festivalContext = null;

  /// Sends the conversation [history] and returns the assistant's reply.
  static Future<String> sendMessage(List<ChatMessage> history) async {
    if (!isConfigured) {
      return 'The chatbot is not set up yet. Please add your API key in '
          'ai_chat_service.dart.';
    }

    final context = await _loadFestivalContext();
    final systemPrompt =
        'You are JomFest Assistant, a friendly helper inside the JomFest '
        'festival ticketing app. Answer customer questions about the '
        'festivals/events below: dates, locations, ticket prices, categories '
        'and what each event is about. Be concise and warm. If a question is '
        'not covered by the festival list, say you only have details on the '
        'festivals currently in the app and suggest they browse the Home page. '
        'Use Malaysian Ringgit (RM) for prices. '
        'IMPORTANT: Do not use any markdown formatting. No asterisks, no bold, '
        'no italics, no bullet symbols, no headers. Plain text only.\n\n'
        '=== CURRENT FESTIVALS ===\n$context';

    try {
      return await _sendToProvider(systemPrompt, history);
    } catch (e) {
      // _sendToProvider throws user-friendly strings; network/other errors
      // fall back to a generic message.
      return e is String
          ? e
          : 'Sorry, I had trouble connecting. Please try again.';
    }
  }

  /// Provider-specific call. Swap this method to change AI providers.
  static Future<String> _sendToProvider(
      String systemPrompt, List<ChatMessage> history) async {
    final body = {
      'system_instruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': history
          .map((m) => {
                'role': m.role,
                'parts': [
                  {'text': m.text}
                ]
              })
          .toList(),
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 600,
      },
    };

    // Retry transient 503 "model busy" responses a couple of times.
    http.Response res;
    var attempt = 0;
    while (true) {
      res = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          // New-style Google keys ("AQ." prefix) authenticate via this header.
          'X-goog-api-key': _apiKey,
        },
        body: jsonEncode(body),
      );
      if (res.statusCode != 503 || attempt >= 2) break;
      attempt++;
      await Future.delayed(Duration(milliseconds: 600 * attempt));
    }

    if (res.statusCode != 200) {
      // Surface a friendly, specific reason for the common failures.
      switch (res.statusCode) {
        case 429:
          throw "I'm getting a lot of requests right now. Please wait a "
              "moment and try again.";
        case 503:
          throw 'The assistant is briefly overloaded. Please try again in a '
              'few seconds.';
        case 400:
        case 401:
        case 403:
          // Most common cause for AQ. keys: the Generative Language API is
          // not enabled for the key's Google Cloud project.
          throw 'Authentication failed. Make sure the "Generative Language '
              'API" is enabled for your key\'s Google Cloud project, then '
              'try again.';
        default:
          // Pull Google's own error message if present, for debugging.
          String detail = 'HTTP ${res.statusCode}';
          try {
            final err = jsonDecode(res.body)['error'];
            if (err is Map && err['message'] != null) {
              detail = err['message'].toString();
            }
          } catch (_) {}
          throw detail;
      }
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      return "I couldn't come up with a reply. Could you rephrase?";
    }
    final parts =
        (candidates.first['content']?['parts'] as List?) ?? const [];
    final text = parts
        .map((p) => (p as Map)['text'] ?? '')
        .join('')
        .toString()
        .trim();
    return text.isEmpty
        ? "I couldn't come up with a reply. Could you rephrase?"
        : _stripMarkdown(text);
  }
}
