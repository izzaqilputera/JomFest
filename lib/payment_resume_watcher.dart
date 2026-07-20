import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'payment_service.dart';

/// Wraps the app and finalizes any payment that was left in-flight when the
/// process was killed during the external ToyyibPay checkout.
///
/// It re-checks the persisted pending payment:
///   * on cold start, once Firebase Auth restores the signed-in user, and
///   * every time the app is resumed (e.g. returning from the browser).
///
/// This makes ticket creation independent of the [PaymentScreen] widget
/// surviving the browser round-trip — the real-device failure mode.
class PaymentResumeWatcher extends StatefulWidget {
  final Widget child;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  const PaymentResumeWatcher({
    super.key,
    required this.child,
    required this.messengerKey,
  });

  @override
  State<PaymentResumeWatcher> createState() => _PaymentResumeWatcherState();
}

class _PaymentResumeWatcherState extends State<PaymentResumeWatcher>
    with WidgetsBindingObserver {
  StreamSubscription<User?>? _authSub;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Fires once auth is restored on cold start (and on later sign-ins).
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) _checkPending();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPending();
    }
  }

  Future<void> _checkPending() async {
    if (_checking) return;
    _checking = true;
    try {
      final pending = await PaymentService.getPending();
      if (pending == null) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return; // wait until auth is restored
      // Only finalize a payment that belongs to the currently signed-in user.
      if (pending['uid'] != user.uid) return;

      final result = await PaymentService.verifyAndFinalize(pending);
      switch (result) {
        case PaymentVerifyResult.paid:
          await PaymentService.clearPending();
          _notify('Your ticket has been confirmed! 🎫');
          break;
        case PaymentVerifyResult.failed:
          await PaymentService.clearPending();
          _notify('Your recent payment did not go through.');
          break;
        case PaymentVerifyResult.pending:
        case PaymentVerifyResult.none:
        case PaymentVerifyResult.error:
          // Leave the pending record in place and try again on next resume.
          break;
      }
    } finally {
      _checking = false;
    }
  }

  void _notify(String message) {
    final messenger = widget.messengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
