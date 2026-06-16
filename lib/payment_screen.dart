import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'theme.dart';

class PaymentScreen extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> event;
  final double amount;
  final String? tierName;

  const PaymentScreen({
    super.key,
    required this.eventId,
    required this.event,
    required this.amount,
    this.tierName,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with WidgetsBindingObserver {
  // ── ToyyibPay sandbox credentials ──────────────────────────────────────────
  static const String _toyyibpayUserSecretKey =
      'q25txb68-ks2n-hohr-kbqp-fbvr4f4930yc';
  static const String _toyyibpayCategoryCode = '6vg6v19v';
  static const String _toyyibpayBaseUrl = 'https://dev.toyyibpay.com';
  // ───────────────────────────────────────────────────────────────────────────

  // Steps: 0 = order summary + confirm, 1 = processing/verify, 2 = success
  int _currentStep = 0;
  bool _isProcessing = false;
  bool _verifying = false;
  String? _paymentId;
  String? _billCode;

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _generateQrData({
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

  int _amountToCents(double amount) => (amount * 100).round();

  String _sanitizeToyyibField(String value, {int maxLength = 60}) {
    final cleaned = value
        .replaceAll(RegExp(r'[^a-zA-Z0-9 @._\-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return '';
    return cleaned.length > maxLength ? cleaned.substring(0, maxLength) : cleaned;
  }

  // ── App lifecycle: auto-verify when user returns from browser ──────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeVerifyOnReturn();
    }
  }

  Future<void> _maybeVerifyOnReturn() async {
    if (!mounted) return;
    if (_billCode == null || _paymentId == null) return;
    if (_currentStep != 1) return; // only on the processing/verify step
    if (_verifying) return;
    await _verifyToyyibPayStatus();
  }

  // ── ToyyibPay API calls ────────────────────────────────────────────────────

  Future<String> _createToyyibPayBill({
    required String externalRef,
    required int amountInCents,
    required String payerName,
    required String payerEmail,
    required String payerPhone,
  }) async {
    final uri = Uri.parse('$_toyyibpayBaseUrl/index.php/api/createBill');

    final rawTitle = _sanitizeToyyibField(
      (widget.event['title'] ?? 'JomFest Ticket').toString(),
      maxLength: 60,
    );
    final billName = rawTitle.isEmpty
        ? 'JomFest Ticket'
        : (rawTitle.length > 30 ? rawTitle.substring(0, 30) : rawTitle);
    final safePayerName = _sanitizeToyyibField(payerName, maxLength: 60);
    final safePayerEmail = _sanitizeToyyibField(payerEmail, maxLength: 80);
    final safePayerPhone = _sanitizeToyyibField(payerPhone, maxLength: 20);

    final resp = await http.post(
      uri,
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: <String, String>{
        'userSecretKey': _toyyibpayUserSecretKey,
        'categoryCode': _toyyibpayCategoryCode,
        'billName': billName,
        'billDescription': 'Ticket purchase for JomFest',
        'billPriceSetting': '1',
        'billPayorInfo': '1',
        'billAmount': amountInCents.toString(),
        'billExternalReferenceNo': externalRef,
        'billTo': safePayerName.isEmpty ? 'JomFest User' : safePayerName,
        'billEmail': safePayerEmail.isEmpty
            ? 'demo@jomfest.local'
            : safePayerEmail,
        'billPhone': safePayerPhone.isEmpty ? '0123456789' : safePayerPhone,
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

  Future<int?> _getToyyibPayPaymentStatus(String billCode) async {
    final uri =
        Uri.parse('$_toyyibpayBaseUrl/index.php/api/getBillTransactions');
    final resp = await http.post(
      uri,
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'userSecretKey': _toyyibpayUserSecretKey,
        'billCode': billCode,
      },
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
          'ToyyibPay getBillTransactions failed (${resp.statusCode})');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
      final statusStr = decoded.first['billpaymentStatus']?.toString() ??
          decoded.first['billPaymentStatus']?.toString();
      return int.tryParse(statusStr ?? '');
    }
    return null; // no transaction record yet
  }

  // ── Verify payment status ──────────────────────────────────────────────────

  Future<void> _verifyToyyibPayStatus() async {
    if (_billCode == null || _paymentId == null) return;
    setState(() => _verifying = true);

    try {
      final status = await _getToyyibPayPaymentStatus(_billCode!);

      // ToyyibPay status codes: 1 = success, 2 = pending, 3 = failed
      if (status == 1) {
        await _finalizeSuccessfulPayment();
      } else if (status == 2) {
        _showSnack('Payment is pending. Please wait a moment and try again.',
            color: Colors.orange);
      } else if (status == 3) {
        await FirebaseFirestore.instance
            .collection('payments')
            .doc(_paymentId)
            .update({'status': 'failed'});
        if (mounted) {
          setState(() => _currentStep = 0);
          _showSnack('Payment failed. Please try again.',
              color: AppColors.error);
        }
      } else {
        // null = no transaction record yet (user hasn't paid or just opened browser)
        _showSnack(
          'No payment found yet. Complete the payment in the browser then tap Verify.',
          color: const Color(0xFF2A2A2A),
        );
      }
    } catch (e) {
      _showSnack('Verification error: $e', color: AppColors.error);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  // ── Finalize: write ticket to Firestore ────────────────────────────────────

  Future<void> _finalizeSuccessfulPayment() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final paymentId = _paymentId!;

    await FirebaseFirestore.instance.runTransaction((txn) async {
      final paymentRef =
          FirebaseFirestore.instance.collection('payments').doc(paymentId);
      final paymentSnap = await txn.get(paymentRef);
      final payment = paymentSnap.data() as Map<String, dynamic>? ?? {};

      // Idempotency guard: don't create duplicate tickets
      if (payment['status'] == 'paid' && payment['ticketCreated'] == true) {
        return;
      }

      final ticketRef =
          FirebaseFirestore.instance.collection('tickets').doc(paymentId);
      final qrData = _generateQrData(
        uid: uid,
        eventId: widget.eventId,
        ticketId: ticketRef.id,
      );

      txn.set(ticketRef, {
        'ticketId': ticketRef.id,
        'userId': uid,
        'uid': uid,
        'eventId': widget.eventId,
        'eventTitle': widget.event['title'],
        'eventDate': widget.event['startDate'],
        'venue': widget.event['venue'] ?? widget.event['location'],
        'organizerName': widget.event['organizerName'],
        'ticketTier': widget.tierName,
        'quantity': 1,
        'amount': widget.amount,
        'price': widget.amount,
        'paymentMethod': 'ToyyibPay (Sandbox)',
        'qrData': qrData,
        'qrVersion': 1,
        'purchasedAt': FieldValue.serverTimestamp(),
        'status': 'confirmed',
        'paymentId': paymentId,
        'billCode': _billCode,
      });

      txn.update(paymentRef, {
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
        'ticketCreated': true,
      });
    });

    // Log purchase interaction for recommendation engine (CBF)
    await FirebaseFirestore.instance.collection('interactions').add({
      'uid': uid,
      'eventId': widget.eventId,
      'type': 'purchase',
      'category': widget.event['category'],
      'featureVector': widget.event['featureVector'],
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      setState(() => _currentStep = 2); // success screen
    }
  }

  // ── Main payment flow: create bill → open browser ─────────────────────────

  Future<void> _processPayment() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // 1. Create pending payment record in Firestore
      final paymentRef =
          FirebaseFirestore.instance.collection('payments').doc();
      _paymentId = paymentRef.id;

      await paymentRef.set({
        'paymentId': paymentRef.id,
        'uid': uid,
        'userId': uid,
        'eventId': widget.eventId,
        'ticketTier': widget.tierName,
        'amount': widget.amount,
        'currency': 'MYR',
        'provider': 'toyyibpay',
        'mode': 'sandbox',
        'status': 'initiated',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Free events should skip ToyyibPay entirely.
      if (widget.amount <= 0) {
        await paymentRef.update({
          'status': 'paid',
          'mode': 'free',
          'paidAt': FieldValue.serverTimestamp(),
          'ticketCreated': false,
        });
        if (mounted) {
          setState(() => _currentStep = 1);
        }
        await _finalizeSuccessfulPayment();
        if (mounted) {
          setState(() => _isProcessing = false);
        }
        return;
      }

      // 2. Get payer info from Firebase Auth
      final email = FirebaseAuth.instance.currentUser?.email;
      final payerEmail =
          (email != null && email.isNotEmpty) ? email : 'demo@jomfest.local';
      final payerName =
          FirebaseAuth.instance.currentUser?.displayName ?? 'JomFest User';
      const payerPhone = '0123456789'; // ToyyibPay requires a phone number

      // 3. Call ToyyibPay createBill
      final billCode = await _createToyyibPayBill(
        externalRef: paymentRef.id,
        amountInCents: _amountToCents(widget.amount),
        payerName: payerName,
        payerEmail: payerEmail,
        payerPhone: payerPhone,
      );

      _billCode = billCode;

      // 4. Save bill code to Firestore
      await paymentRef.update({
        'status': 'checkout_created',
        'billCode': billCode,
        'checkoutUrl': '$_toyyibpayBaseUrl/$billCode',
      });

      // 5. Open ToyyibPay checkout in external browser
      final checkoutUri = Uri.parse('$_toyyibpayBaseUrl/$billCode');
      final launched =
          await launchUrl(checkoutUri, mode: LaunchMode.externalApplication);

      if (!launched) throw Exception('Could not open browser for payment.');

      // 6. Move to "waiting for verification" step
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _currentStep = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showSnack('Payment setup failed: $e', color: AppColors.error);
      }
    }
  }

  // ── Snackbar helper ────────────────────────────────────────────────────────

  void _showSnack(String message, {required Color color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: _currentStep != 2
          ? AppBar(
              backgroundColor: AppColors.scaffoldBg,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: AppColors.textPrimary),
                onPressed: () {
                  if (_currentStep == 0) {
                    Navigator.pop(context);
                  }
                  // Don't allow back from step 1 (processing) — payment is in flight
                },
              ),
              title: Text(
                _currentStep == 0 ? 'Confirm Payment' : 'Processing...',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      body: _buildCurrentStep(),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildOrderSummary();
      case 1:
        return _buildProcessing();
      case 2:
        return _buildSuccess();
      default:
        return _buildOrderSummary();
    }
  }

  // ── Step 0: Order summary + Pay button ────────────────────────────────────

  Widget _buildOrderSummary() {
    return SingleChildScrollView(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Order summary card ──────────────────────────────────────────
          Container(
            padding: AppSpacing.cardPadding,
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Order Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          const Icon(Icons.festival, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.event['title'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            widget.event['startDate'] ?? '',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.grey),
                          ),
                          if (widget.tierName != null) ...[
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.tierName!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      widget.amount == 0
                          ? 'FREE'
                          : 'RM ${widget.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    Text(
                      widget.amount == 0
                          ? 'FREE'
                          : 'RM ${widget.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── ToyyibPay info banner ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border:
                  Border.all(color: AppColors.primary.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.open_in_new_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'You will be redirected to ToyyibPay to complete payment securely. '
                    'FPX, cards and e-wallets are all supported.',
                    style: TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Security note ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.successNoteBg,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                const Icon(Icons.security,
                    color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your payment is secured with 256-bit SSL encryption',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.successStrong),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Pay button ──────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                disabledBackgroundColor:
                    AppColors.primary.withOpacity(0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: AppColors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      widget.amount == 0
                          ? 'Confirm Free Ticket'
                          : 'Pay RM ${widget.amount.toStringAsFixed(2)} via ToyyibPay',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Step 1: Waiting / verify ───────────────────────────────────────────────

  Widget _buildProcessing() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.open_in_new_rounded,
                size: 64, color: AppColors.primary.withOpacity(0.9)),
            const SizedBox(height: 18),
            const Text(
              'Complete Payment in Browser',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your ToyyibPay checkout page has been opened in your browser.\n\n'
              'After completing the payment, come back here and tap "Verify Payment".',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey600, height: 1.5),
            ),
            const SizedBox(height: 24),

            // Bill code badge
            if (_billCode != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border:
                      Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_outlined,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Bill: $_billCode',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.primary),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 28),

            // Re-open browser button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () async {
                  if (_billCode == null) return;
                  final uri =
                      Uri.parse('$_toyyibpayBaseUrl/$_billCode');
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Re-open Payment Page'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                      color: AppColors.primary.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Verify button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _verifying ? null : _verifyToyyibPayStatus,
                icon: _verifying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.white),
                      )
                    : const Icon(Icons.verified_outlined),
                label: Text(_verifying ? 'Verifying…' : 'Verify Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Success ────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.huge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: AppColors.successSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: AppColors.success, size: 60),
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Your ticket for',
                style: TextStyle(color: AppColors.grey600)),
            const SizedBox(height: 4),
            Text(
              widget.event['title'] ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            const Text('has been confirmed!',
                style: TextStyle(color: AppColors.grey600)),
            const SizedBox(height: 32),

            // Ticket summary
            Container(
              width: double.infinity,
              padding: AppSpacing.cardPadding,
              decoration: BoxDecoration(
                color: AppColors.scaffoldBg,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  _buildTicketRow('Event', widget.event['title'] ?? ''),
                  const Divider(height: 16),
                  if (widget.tierName != null) ...[
                    _buildTicketRow('Category', widget.tierName!),
                    const Divider(height: 16),
                  ],
                  _buildTicketRow(
                      'Date', widget.event['startDate'] ?? ''),
                  const Divider(height: 16),
                  _buildTicketRow(
                    'Venue',
                    widget.event['venue']?.isNotEmpty == true
                        ? widget.event['venue']
                        : widget.event['location'] ?? '',
                  ),
                  const Divider(height: 16),
                  _buildTicketRow('Payment', 'ToyyibPay (Sandbox)'),
                  const Divider(height: 16),
                  _buildTicketRow(
                    'Amount',
                    widget.amount == 0
                        ? 'FREE'
                        : 'RM ${widget.amount.toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Back to Home',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 13, color: AppColors.grey600)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}