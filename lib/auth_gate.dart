import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'admin_dashboard.dart';
import 'organizer_registration.dart';
import 'organizer_dashboard.dart';
import 'home_screen.dart';
import 'theme.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.primary,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.white),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(snapshot.data!.uid)
              .snapshots(includeMetadataChanges: true),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: AppColors.primary,
                body: Center(
                  child:
                  CircularProgressIndicator(color: AppColors.white),
                ),
              );
            }

            if (userSnapshot.hasError) {
              return const HomeScreen();
            }

            final userDoc = userSnapshot.data;
            if (userDoc == null) {
              return const HomeScreen();
            }

            if (!userDoc.exists) {
              return const HomeScreen();
            }

            final role = (userDoc.data() as Map<String, dynamic>?)?['role'] ??
                'customer';

            if (role == 'admin') {
              return const AdminDashboard();
            } else if (role == 'organizer') {
              return const OrganizerGate();
            } else {
              return const HomeScreen();
            }
          },
        );
      },
    );
  }
}

class OrganizerGate extends StatelessWidget {
  const OrganizerGate({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('organizers')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.primary,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.white),
            ),
          );
        }

        // No application yet
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const OrganizerRegistrationScreen();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final isVerified = data['isVerified'] ?? false;
        final status = data['status'] ?? 'pending';

        // Rejected
        if (status == 'rejected') {
          return Scaffold(
            backgroundColor: AppColors.scaffoldBg,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.huge),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cancel_outlined,
                        size: 64, color: AppColors.error),
                    const SizedBox(height: 16),
                    const Text(
                      'Application Rejected',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your application was rejected. Please contact support.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.grey600),
                    ),
                    const SizedBox(height: 32),
                    OutlinedButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                      ),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Pending verification
        if (!isVerified) {
          return Scaffold(
            backgroundColor: AppColors.scaffoldBg,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.huge),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.hourglass_empty,
                        size: 64, color: AppColors.primary),
                    const SizedBox(height: 16),
                    const Text(
                      'Application Under Review',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Admin is reviewing your application. Please wait 1-2 business days.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.grey600),
                    ),
                    const SizedBox(height: 32),
                    OutlinedButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                            color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                      ),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Verified organizer
        return const OrganizerDashboard();
      },
    );
  }
}