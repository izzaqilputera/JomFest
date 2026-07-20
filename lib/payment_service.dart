import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Result of checking (and possibly finalizing) a payment.
enum PaymentVerifyResult {
  /// Payment confirmed and ticket created (or already existed).
  paid,

  /// Payment is still pending on ToyyibPay — try again later.
  pending,

  /// Payment failed / was cancelled.
  failed,

  /// No transaction record found yet (user hasn't paid).
  none,

  /// Network / unexpected error — safe to retry later.
  error,
}

/// Central place for the ToyyibPay integration and, crucially, for
/// *persisting* the in-flight payment so it can be finalized even if the
/// app process is killed while the user is in the external browser.
///
/// Real Android devices frequently kill a backgrounded app during the
/// external checkout round-trip. The old design kept the bill code and
/// payment id only in [State] fields, so after process death the ticket
/// was never created. Persisting to [SharedPreferences] and re-checking on
/// launch/resume closes that gap.
class PaymentService {
  // ── ToyyibPay sandbox credentials ──────────────────────────────────────────
  static const String toyyibpayUserSecretKey =
      'q25txb68-ks2n-hohr-kbqp-fbvr4f4930yc';
  static const String toyyibpayCategoryCode = '6vg6v19v';
  static const String toyyibpayBaseUrl = 'https://dev.toyyibpay.com';
  // ───────────────────────────────────────────────────────────────────────────

  static const String _pendingKey = 'pending_payment_v1';

  // ── Pending-payment persistence ────────────────────────────────────────────

  /// Persists everything needed to finalize a ticket after the browser trip.
  /// Called immediately after the ToyyibPay bill is created, *before* the
  /// external browser is opened.
  static Future<void> savePending(Map<String, dynamic> pending) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.setString(_pendingKey, jsonEncode(pending));
    } catch (_) {
      // featureVector (or some other event field) wasn't JSON-encodable.
      // Drop the non-critical recommendation payload and retry — the ticket
      // itself is far more important than the interaction log.
      final safe = Map<String, dynamic>.from(pending)..remove('featureVector');
      await prefs.setString(_pendingKey, jsonEncode(safe));
    }
  }

  /// Returns the persisted pending payment, or null if there isn't one.
  static Future<Map<String, dynamic>?> getPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Corrupt entry — clear it so we don't loop on it forever.
      await prefs.remove(_pendingKey);
    }
    return null;
  }

  static Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
  }

  // ── ToyyibPay API calls ────────────────────────────────────────────────────

  static Future<String> createBill({
    required String externalRef,
    required int amountInCents,
    required String billName,
    required String payerName,
    required String payerEmail,
    required String payerPhone,
  }) async {
    final uri = Uri.parse('$toyyibpayBaseUrl/index.php/api/createBill');

    final resp = await http.post(
      uri,
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: <String, String>{
        'userSecretKey': toyyibpayUserSecretKey,
        'categoryCode': toyyibpayCategoryCode,
        'billName': billName,
        'billDescription': 'Ticket purchase for JomFest',
        'billPriceSetting': '1',
        'billPayorInfo': '1',
        'billAmount': amountInCents.toString(),
        'billExternalReferenceNo': externalRef,
        'billTo': payerName.isEmpty ? 'JomFest User' : payerName,
        'billEmail': payerEmail.isEmpty ? 'demo@jomfest.local' : payerEmail,
        'billPhone': payerPhone.isEmpty ? '0123456789' : payerPhone,
        // '0' = all channels (FPX + card + e-wallet), '1' = FPX only, '2' = card only
        'billPaymentChannel': '0',
      },
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('ToyyibPay createBill failed (${resp.statusCode})');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
      final billCode =
          (decoded.first['BillCode'] ?? decoded.first['billCode'])?.toString();
      if (billCode != null && billCode.isNotEmpty) return billCode;
    }
    throw Exception('ToyyibPay returned unexpected response: ${resp.body}');
  }

  /// Returns the ToyyibPay payment status code:
  /// 1 = success, 2 = pending, 3 = failed, null = no transaction record yet.
  static Future<int?> getBillStatus(String billCode) async {
    final uri = Uri.parse('$toyyibpayBaseUrl/index.php/api/getBillTransactions');
    final resp = await http.post(
      uri,
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'userSecretKey': toyyibpayUserSecretKey,
        'billCode': billCode,
      },
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('ToyyibPay getBillTransactions failed (${resp.statusCode})');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
      final statusStr = decoded.first['billpaymentStatus']?.toString() ??
          decoded.first['billPaymentStatus']?.toString();
      return int.tryParse(statusStr ?? '');
    }
    return null; // no transaction record yet
  }

  // ── Verify + finalize ──────────────────────────────────────────────────────

  /// Checks the payment status and, if paid, creates the ticket. Safe to call
  /// repeatedly — ticket creation is idempotent (keyed by paymentId).
  static Future<PaymentVerifyResult> verifyAndFinalize(
      Map<String, dynamic> pending) async {
    final paymentId = pending['paymentId'] as String?;
    if (paymentId == null) return PaymentVerifyResult.error;

    final isFree = pending['isFree'] == true;
    final billCode = pending['billCode'] as String?;

    // Free tickets have no ToyyibPay bill to check — just finalize.
    if (isFree || billCode == null) {
      try {
        await finalizeTicket(pending);
        return PaymentVerifyResult.paid;
      } catch (_) {
        return PaymentVerifyResult.error;
      }
    }

    try {
      final status = await getBillStatus(billCode);
      if (status == 1) {
        await finalizeTicket(pending);
        return PaymentVerifyResult.paid;
      } else if (status == 2) {
        return PaymentVerifyResult.pending;
      } else if (status == 3) {
        await FirebaseFirestore.instance
            .collection('payments')
            .doc(paymentId)
            .update({'status': 'failed'});
        return PaymentVerifyResult.failed;
      }
      return PaymentVerifyResult.none;
    } catch (_) {
      return PaymentVerifyResult.error;
    }
  }

  /// Writes the ticket to Firestore inside a transaction. Idempotent: if the
  /// ticket was already created for this paymentId, it does nothing. Only logs
  /// a recommendation interaction when a ticket is actually created.
  static Future<void> finalizeTicket(Map<String, dynamic> pending) async {
    final paymentId = pending['paymentId'] as String;
    final uid = pending['uid'] as String;
    final eventId = pending['eventId'] as String;
    final amount = (pending['amount'] as num?)?.toDouble() ?? 0.0;
    final billCode = pending['billCode'] as String?;

    final firestore = FirebaseFirestore.instance;

    final created = await firestore.runTransaction<bool>((txn) async {
      final paymentRef = firestore.collection('payments').doc(paymentId);
      final paymentSnap = await txn.get(paymentRef);
      final payment = paymentSnap.data() ?? {};

      // Idempotency guard: don't create duplicate tickets.
      if (payment['status'] == 'paid' && payment['ticketCreated'] == true) {
        return false;
      }

      final ticketRef = firestore.collection('tickets').doc(paymentId);
      final qrData = _generateQrData(
        uid: uid,
        eventId: eventId,
        ticketId: ticketRef.id,
      );

      txn.set(ticketRef, {
        'ticketId': ticketRef.id,
        'userId': uid,
        'uid': uid,
        'eventId': eventId,
        'eventTitle': pending['eventTitle'],
        'eventDate': pending['eventDate'],
        'venue': pending['venue'],
        'organizerName': pending['organizerName'],
        'ticketTier': pending['tierName'],
        'quantity': 1,
        'amount': amount,
        'price': amount,
        'paymentMethod': 'ToyyibPay (Sandbox)',
        'qrData': qrData,
        'qrVersion': 1,
        'purchasedAt': FieldValue.serverTimestamp(),
        'status': 'confirmed',
        'paymentId': paymentId,
        'billCode': billCode,
      });

      txn.update(paymentRef, {
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
        'ticketCreated': true,
      });

      return true;
    });

    if (created) {
      // Log purchase interaction for recommendation engine (CBF).
      await firestore.collection('interactions').add({
        'uid': uid,
        'eventId': eventId,
        'type': 'purchase',
        'category': pending['category'],
        'featureVector': pending['featureVector'],
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _generateQrData({
    required String uid,
    required String eventId,
    required String ticketId,
  }) {
    final rnd = Random.secure();
    final nonce = List<int>.generate(16, (_) => rnd.nextInt(256));
    final nonceB64 = base64UrlEncode(nonce).replaceAll('=', '');
    final ts = DateTime.now().toUtc().toIso8601String();
    return 'JOMFEST|$uid|$eventId|$ticketId|$ts|$nonceB64';
  }

  static int amountToCents(double amount) => (amount * 100).round();

  static String sanitizeToyyibField(String value, {int maxLength = 60}) {
    final cleaned = value
        .replaceAll(RegExp(r'[^a-zA-Z0-9 @._\-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return '';
    return cleaned.length > maxLength ? cleaned.substring(0, maxLength) : cleaned;
  }
}
