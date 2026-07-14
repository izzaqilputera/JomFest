import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'theme.dart';

class OrganizerRegistrationScreen extends StatefulWidget {
  const OrganizerRegistrationScreen({super.key});

  @override
  State<OrganizerRegistrationScreen> createState() =>
      _OrganizerRegistrationScreenState();
}

class _OrganizerRegistrationScreenState
    extends State<OrganizerRegistrationScreen> {
  final _companyNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  File? _icFile;
  String? _icFileName;

  @override
  void dispose() {
    _companyNameController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickIC() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() {
        _icFile = File(picked.path);
        _icFileName = picked.name;
      });
    }
  }

  Future<String?> _uploadIC(String uid) async {
    if (_icFile == null) return null;
    final bytes = await _icFile!.readAsBytes();
    final base64String = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64String';
  }

  Future<void> _submitApplication() async {
    if (_companyNameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }
    if (_icFile == null) {
      setState(() => _errorMessage = 'Please upload your IC or business document.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final email = FirebaseAuth.instance.currentUser!.email;

      // Upload IC to Firebase Storage
      final icUrl = await _uploadIC(uid);

      // Save organizer application to Firestore
      await FirebaseFirestore.instance
          .collection('organizers')
          .doc(uid)
          .set({
        'uid': uid,
        'email': email,
        'companyName': _companyNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'description': _descriptionController.text.trim(),
        'icUrl': icUrl,
        'isVerified': false,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });

      // Update user document status
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'organizerStatus': 'pending'});

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle,
                    color: AppColors.success, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Application Submitted!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your application is under review. We\'ll notify you once verified.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.grey600),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to submit. Please try again. ($e)');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: AppColors.textPrimary),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
          },
        ),
        title: Text(
          'Organizer Application',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header banner
            Container(
              width: double.infinity,
              padding: AppSpacing.cardPadding,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Submit your details and IC for verification. Admin will review within 1-2 business days.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.grey700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Company name
            _buildLabel('Company / Organization Name'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _companyNameController,
              hint: 'e.g. Konsert Hebat Sdn Bhd',
              icon: Icons.business_outlined,
            ),
            const SizedBox(height: 20),

            // Phone
            _buildLabel('Phone Number'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _phoneController,
              hint: 'e.g. 0123456789',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),

            // Description
            _buildLabel('About Your Organization'),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tell us about your organization...',
                filled: true,
                fillColor: AppColors.primarySurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // IC Upload
            _buildLabel('Upload IC / Business Document'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickIC,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: _icFile != null
                        ? AppColors.primary
                        : AppColors.transparent,
                    width: 2,
                  ),
                ),
                child: _icFile != null
                    ? Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppColors.success),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _icFileName ?? 'File selected',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: _pickIC,
                      child: const Text('Change'),
                    ),
                  ],
                )
                    : Column(
                  children: [
                    const Icon(Icons.upload_file,
                        size: 40, color: AppColors.primary),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap to upload',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'IC, passport or business registration',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.grey500),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Error
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.errorSurface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitApplication,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: AppColors.white,
                    strokeWidth: 2.5,
                  ),
                )
                    : const Text(
                  'Submit Application',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: AppColors.primarySurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide:
          const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}