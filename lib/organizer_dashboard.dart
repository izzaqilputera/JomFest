import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'theme.dart';
import 'analytics_screen.dart';

bool _posterPickerInProgress = false;
const double _posterAspectRatio = 16 / 9;

Future<File?> _pickAndCropPosterImage(BuildContext context) async {
  if (_posterPickerInProgress) return null;
  _posterPickerInProgress = true;

  final picker = ImagePicker();
  try {
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );

    if (pickedFile == null) return null;

    final uiSettings = <PlatformUiSettings>[
      AndroidUiSettings(
        toolbarTitle: 'Crop Poster',
        toolbarColor: AppColors.primary,
        toolbarWidgetColor: AppColors.black,
        initAspectRatio: CropAspectRatioPreset.ratio16x9,
        lockAspectRatio: true,
      ),
      IOSUiSettings(
        title: 'Crop Poster',
        aspectRatioLockEnabled: true,
        resetAspectRatioEnabled: false,
      ),
      if (kIsWeb)
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          size: const CropperSize(width: 520, height: 700),
        ),
    ];

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: uiSettings,
    );

    if (croppedFile == null) return null;
    return File(croppedFile.path);
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  } finally {
    _posterPickerInProgress = false;
  }
}

// ── Ticket tier helpers (shared by Create & Edit screens) ────

/// Holds the text controllers for a single editable ticket category row.
class _TierControllers {
  final TextEditingController name;
  final TextEditingController price;
  _TierControllers({String name = '', String price = ''})
      : name = TextEditingController(text: name),
        price = TextEditingController(text: price);
  void dispose() {
    name.dispose();
    price.dispose();
  }
}

/// Formats a price as a clean string for an input field (2000.0 -> "2000").
String _formatTierPrice(double p) =>
    p == p.roundToDouble() ? p.toInt().toString() : p.toString();

/// Reads the ticket tiers from an event map, falling back to the legacy
/// single `ticketPrice` field for older events that have no `ticketTiers`.
List<Map<String, dynamic>> _extractTiers(Map<String, dynamic> event) {
  final raw = event['ticketTiers'];
  if (raw is List && raw.isNotEmpty) {
    return raw.whereType<Map>().map((e) {
      final price = e['price'];
      return <String, dynamic>{
        'name': (e['name'] ?? 'Standard').toString(),
        'price':
            price is num ? price.toDouble() : double.tryParse('$price') ?? 0.0,
      };
    }).toList();
  }
  final p = event['ticketPrice'];
  final price = p is num ? p.toDouble() : double.tryParse('$p') ?? 0.0;
  return [
    {'name': price == 0 ? 'Free Entry' : 'Standard', 'price': price}
  ];
}

/// Builds the list of tier maps to save from the editable controllers.
/// Skips rows with an empty name; guarantees at least one tier.
List<Map<String, dynamic>> _collectTiers(List<_TierControllers> tiers) {
  final result = <Map<String, dynamic>>[];
  for (final t in tiers) {
    final name = t.name.text.trim();
    if (name.isEmpty) continue;
    final price = double.tryParse(t.price.text.trim()) ?? 0;
    result.add({'name': name, 'price': price});
  }
  if (result.isEmpty) result.add({'name': 'Standard', 'price': 0.0});
  return result;
}

/// The lowest price across all tiers — saved as `ticketPrice` for backward
/// compatibility (list display, feature vector, free-event handling).
double _minTierPrice(List<Map<String, dynamic>> tiers) {
  double m = tiers.first['price'] as double;
  for (final t in tiers) {
    final p = t['price'] as double;
    if (p < m) m = p;
  }
  return m;
}

InputDecoration _tierFieldDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.primarySurface,
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
  );
}

/// The "Ticket Categories" editor: a name + price row per tier, with
/// add/remove controls. Used by both Create and Edit event screens.
Widget _buildTierEditor({
  required List<_TierControllers> tiers,
  required VoidCallback onAdd,
  required ValueChanged<int> onRemove,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ...tiers.asMap().entries.map((entry) {
        final i = entry.key;
        final tier = entry.value;
        final canRemove = tiers.length > 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: tier.name,
                  decoration: _tierFieldDecoration('Category (e.g. VIP)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: tier.price,
                  keyboardType: TextInputType.number,
                  decoration: _tierFieldDecoration('RM'),
                ),
              ),
              SizedBox(
                width: 44,
                child: IconButton(
                  onPressed: canRemove ? () => onRemove(i) : null,
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color:
                        canRemove ? AppColors.error : AppColors.grey600,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
      const SizedBox(height: 2),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('Add category'),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
      ),
    ],
  );
}

class OrganizerDashboard extends StatefulWidget {
  const OrganizerDashboard({super.key});

  @override
  State<OrganizerDashboard> createState() => _OrganizerDashboardState();
}

class _OrganizerDashboardState extends State<OrganizerDashboard> {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final Set<String> _deletingEventIds = <String>{};

  Future<void> _confirmDeleteEvent(
      BuildContext context, String eventId, String eventTitle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete event?'),
          content: Text(
            'This will permanently delete "$eventTitle". This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await _deleteEvent(context, eventId);
  }

  Future<void> _deleteEvent(BuildContext context, String eventId) async {
    if (_deletingEventIds.contains(eventId)) return;
    setState(() => _deletingEventIds.add(eventId));

    try {
      final docRef = FirebaseFirestore.instance.collection('events').doc(eventId);
      final snap = await docRef.get();
      final ownerUid = snap.data()?['organizerUid'];
      if (!snap.exists || ownerUid != uid) {
        throw Exception('You can only delete your own events.');
      }

      await docRef.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event deleted successfully.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete event: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _deletingEventIds.remove(eventId));
      }
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Events',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Organizer Dashboard',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: AppColors.primarySurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: AppColors.primary.withOpacity(0.35),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                OrganizerAnalyticsScreen(organizerUid: uid),
                          ),
                        );
                      },
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.bar_chart_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.primarySurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: AppColors.primary.withOpacity(0.35),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CreateEventScreen(),
                          ),
                        );
                      },
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.add_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () async => await FirebaseAuth.instance.signOut(),
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
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('events')
                    .where('organizerUid', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }

                  final events = snapshot.data?.docs ?? [];

                  if (events.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.festival_outlined,
                                size: 60, color: AppColors.grey600),
                            const SizedBox(height: 16),
                            Text(
                              'No events yet',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Create your first event to submit for review',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event =
                          events[index].data() as Map<String, dynamic>;
                      final eventId = events[index].id;
                      return _buildEventCard(event, eventId, context);
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

  Widget _buildEventCard(
      Map<String, dynamic> event, String eventId, BuildContext context) {
    final status = event['status'] ?? 'pending';
    final isDeleting = _deletingEventIds.contains(eventId);
    final eventTitle = (event['title'] ?? 'Untitled').toString();
    Color statusColor;
    Color statusBg;
    IconData statusIcon;

    switch (status) {
      case 'published':
        statusColor = AppColors.success;
        statusBg = AppColors.successSurface;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusBg = AppColors.errorSurface;
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = AppColors.warning;
        statusBg = AppColors.warningSurface;
        statusIcon = Icons.hourglass_empty;
    }

    final hasImage = event['imageUrl'] != null &&
        (event['imageUrl'] as String).isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event Image
          if (hasImage)
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.card),
                topRight: Radius.circular(AppRadius.card),
              ),
              child: _buildEventImage(event['imageUrl']),
            ),
          Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event['title'] ?? 'Untitled',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            status[0].toUpperCase() + status.substring(1),
                            style: TextStyle(
                              fontSize: 11,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        event['category'] ?? 'General',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (event['location'] != null) ...[
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: AppColors.grey),
                      const SizedBox(width: 2),
                      Text(
                        event['location'],
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.grey),
                      ),
                    ],
                  ],
                ),
                if (event['startDate'] != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 13, color: AppColors.grey),
                      const SizedBox(width: 4),
                      Text(
                        event['startDate'],
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.grey),
                      ),
                    ],
                  ),
                ],
                if (status == 'rejected' &&
                    event['rejectionReason'] != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.errorSurface,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 14, color: AppColors.error),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Reason: ${event['rejectionReason']}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Action Buttons
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (status == 'published') ...[
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: OutlinedButton.icon(
                            onPressed: isDeleting
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EditEventScreen(
                                          eventId: eventId,
                                          event: event,
                                        ),
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: OutlinedButton.icon(
                          onPressed: isDeleting
                              ? null
                              : () => _confirmDeleteEvent(
                                  context, eventId, eventTitle),
                          icon: isDeleting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.error,
                                  ),
                                )
                              : const Icon(Icons.delete_outline),
                          label: Text(isDeleting ? 'Deleting...' : 'Delete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildEventImage(String imageUrl) {
    // Check if it's a base64 data URL
    if (imageUrl.startsWith('data:image')) {
      try {
        final base64String =
            imageUrl.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildImageErrorContainer();
          },
        );
      } catch (e) {
        return _buildImageErrorContainer();
      }
    } else {
      // It's a network URL (if any)
      return Image.network(
        imageUrl,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildImageErrorContainer();
        },
      );
    }
  }

  Widget _buildImageErrorContainer() {
    return Container(
      height: 180,
      color: AppColors.primarySurface,
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined,
            color: AppColors.grey),
      ),
    );
  }
}

// ── CREATE EVENT SCREEN ──────────────────────────────────────

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _venueController = TextEditingController();
  final List<_TierControllers> _tiers = [
    _TierControllers(name: 'Standard'),
  ];
  final List<String> _selectedKeywords = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedCategory = 'Music';
  String _selectedType = 'In Person';
  DateTime? _startDate;
  DateTime? _endDate;
  File? _selectedImage;

  final List<String> _categories = [
    'Music', 'Food & Drink', 'Arts & Culture', 'Sports',
    'Technology', 'Family', 'Health & Wellness',
    'Business', 'Comedy', 'Education',
  ];

  final List<String> _types = ['In Person', 'Virtual', 'Hybrid'];

  static const List<String> _allTags = [
    'Music', 'Food & Drink', 'Arts & Culture', 'Sports', 'Technology',
    'Family', 'Health & Wellness', 'Business', 'Comedy', 'Education',
    'Live Performance', 'Outdoor', 'Indoor', 'Night Event', 'Weekend',
    'Workshop', 'Exhibition', 'Competition', 'Festival', 'Networking',
    'Family Friendly', 'Kids Friendly', 'Free Entry',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _venueController.dispose();
    for (final t in _tiers) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final selected = await _pickAndCropPosterImage(context);
    if (selected != null) {
      setState(() {
        _selectedImage = selected;
      });
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  List<double> _buildFeatureVector(double price) {
    final vector = List<double>.filled(17, 0);
    final categories = [
      'Music', 'Food & Drink', 'Arts & Culture', 'Sports',
      'Technology', 'Family', 'Health & Wellness',
      'Business', 'Comedy', 'Education',
    ];
    final types = ['In Person', 'Virtual', 'Hybrid'];

    final catIdx = categories.indexOf(_selectedCategory);
    if (catIdx >= 0) vector[catIdx] = 1;

    final typeIdx = types.indexOf(_selectedType);
    if (typeIdx >= 0) vector[10 + typeIdx] = 1;

    if (price == 0) vector[13] = 1;
    else if (price <= 50) vector[14] = 1;
    else if (price <= 100) vector[15] = 1;
    else vector[16] = 1;

    return vector;
  }

  Future<void> _submitEvent() async {
    if (_titleController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        _startDate == null ||
        _endDate == null) {
      setState(() =>
      _errorMessage = 'Please fill in all required fields.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Get organizer info
      final orgDoc = await FirebaseFirestore.instance
          .collection('organizers')
          .doc(uid)
          .get();
      final organizerName =
          orgDoc.data()?['companyName'] ?? 'Unknown';

      final tiers = _collectTiers(_tiers);
      final minPrice = _minTierPrice(tiers);

      // Create a temporary document to get ID for image storage
      final tempDoc = await FirebaseFirestore.instance
          .collection('events')
          .add({
        'organizerUid': uid,
        'organizerName': organizerName,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'type': _selectedType,
        'location': _locationController.text.trim(),
        'venue': _venueController.text.trim(),
        'startDate':
        '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}',
        'endDate':
        '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
        'ticketTiers': tiers,
        'ticketPrice': minPrice,
        'keywords': _selectedKeywords,
        'featureVector': _buildFeatureVector(minPrice),
        'status': 'pending',
        'imageUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Upload image if selected
      String imageUrl = '';
      if (_selectedImage != null) {
        try {
          final bytes = await _selectedImage!.readAsBytes();
          final base64String = base64Encode(bytes);
          imageUrl = 'data:image/jpeg;base64,$base64String';
          print('Image converted to base64 (${bytes.length} bytes)');

          // Update document with image URL
          await tempDoc.update({'imageUrl': imageUrl});
        } catch (e) {
          print('Image conversion error: $e');
          // Image conversion failed, but event was created
          // Continue anyway
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Event submitted for review!'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Submit event error: $e');
      setState(
              () => _errorMessage = 'Failed to submit. Error: ${e.toString()}');
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Event',
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
            // Event Poster
            _buildLabel('Event Poster'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickImage,
              child: AspectRatio(
                aspectRatio: _posterAspectRatio,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  size: 50, color: AppColors.primary),
                              const SizedBox(height: 12),
                              Text(
                                'Add Event Poster',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to select poster image (16:9)',
              style: const TextStyle(fontSize: 12, color: AppColors.grey500),
            ),
            const SizedBox(height: 20),

            // Title
            _buildLabel('Event Title *'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _titleController,
              hint: 'e.g. Rock the Valley Festival 2025',
              icon: Icons.title,
            ),
            const SizedBox(height: 20),

            // Description
            _buildLabel('Description'),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: _inputDecoration(
                  'Tell attendees about your event...', null),
            ),
            const SizedBox(height: 20),

            // Category
            _buildLabel('Category *'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  items: _categories.map((cat) {
                    return DropdownMenuItem(
                        value: cat, child: Text(cat));
                  }).toList(),
                  onChanged: (val) =>
                      setState(() => _selectedCategory = val!),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Type
            _buildLabel('Event Type *'),
            const SizedBox(height: 8),
            Row(
              children: _types.map((type) {
                final selected = _selectedType == type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedType = type),
                    child: Container(
                      margin: EdgeInsets.only(
                          right: type != _types.last ? 8 : 0),
                      padding:
                      const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.cardBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        type,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppColors.black
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Location
            _buildLabel('Location *'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _locationController,
              hint: 'e.g. Kuala Lumpur',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 20),

            // Venue
            _buildLabel('Venue'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _venueController,
              hint: 'e.g. Stadium Merdeka',
              icon: Icons.place_outlined,
            ),
            const SizedBox(height: 20),

            // Dates
            _buildLabel('Event Dates *'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(true),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: _startDate != null
                              ? AppColors.primary
                              : AppColors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16,
                              color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            _startDate != null
                                ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                : 'Start date',
                            style: TextStyle(
                              fontSize: 13,
                              color: _startDate != null
                                  ? AppColors.textPrimary
                                  : AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(false),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: _endDate != null
                              ? AppColors.primary
                              : AppColors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16,
                              color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            _endDate != null
                                ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                : 'End date',
                            style: TextStyle(
                              fontSize: 13,
                              color: _endDate != null
                                  ? AppColors.textPrimary
                                  : AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Ticket Categories
            _buildLabel('Ticket Categories'),
            const SizedBox(height: 4),
            const Text(
              'Add one row per seat type. Use price 0 for free entry.',
              style: TextStyle(fontSize: 12, color: AppColors.grey500),
            ),
            const SizedBox(height: 12),
            _buildTierEditor(
              tiers: _tiers,
              onAdd: () => setState(() => _tiers.add(_TierControllers())),
              onRemove: (i) => setState(() {
                _tiers.removeAt(i).dispose();
              }),
            ),
            const SizedBox(height: 20),

            // Tags
            _buildLabel('Tags'),
            const SizedBox(height: 4),
            const Text(
              'Select tags that describe your event',
              style: TextStyle(fontSize: 12, color: AppColors.grey500),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allTags.map((tag) {
                final selected = _selectedKeywords.contains(tag);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedKeywords.remove(tag);
                    } else {
                      _selectedKeywords.add(tag);
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.transparent,
                      ),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: selected ? AppColors.white : AppColors.primary,
                      ),
                    ),
                  ),
                );
              }).toList(),
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

            // Submit
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.black,
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
                    color: AppColors.black,
                    strokeWidth: 2.5,
                  ),
                )
                    : const Text(
                  'Submit for Review',
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

  InputDecoration _inputDecoration(String hint, IconData? icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
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
      decoration: _inputDecoration(hint, icon),
    );
  }
}

// ── EDIT EVENT SCREEN ────────────────────────────────────────

class EditEventScreen extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> event;

  const EditEventScreen({
    super.key,
    required this.eventId,
    required this.event,
  });

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _venueController;
  late List<_TierControllers> _tiers;
  List<String> _selectedKeywords = [];
  bool _isLoading = false;
  String? _errorMessage;
  late String _selectedCategory;
  late String _selectedType;
  late DateTime? _startDate;
  late DateTime? _endDate;
  File? _selectedImage;
  String? _existingImageUrl;

  final List<String> _categories = [
    'Music', 'Food & Drink', 'Arts & Culture', 'Sports',
    'Technology', 'Family', 'Health & Wellness',
    'Business', 'Comedy', 'Education',
  ];

  final List<String> _types = ['In Person', 'Virtual', 'Hybrid'];

  static const List<String> _allTags = [
    'Music', 'Food & Drink', 'Arts & Culture', 'Sports', 'Technology',
    'Family', 'Health & Wellness', 'Business', 'Comedy', 'Education',
    'Live Performance', 'Outdoor', 'Indoor', 'Night Event', 'Weekend',
    'Workshop', 'Exhibition', 'Competition', 'Festival', 'Networking',
    'Family Friendly', 'Kids Friendly', 'Free Entry',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event['title'] ?? '');
    _descriptionController =
        TextEditingController(text: widget.event['description'] ?? '');
    _locationController =
        TextEditingController(text: widget.event['location'] ?? '');
    _venueController =
        TextEditingController(text: widget.event['venue'] ?? '');
    _tiers = _extractTiers(widget.event)
        .map((t) => _TierControllers(
              name: t['name'] as String,
              price: _formatTierPrice(t['price'] as double),
            ))
        .toList();
    _selectedKeywords = List<String>.from(widget.event['keywords'] ?? []);

    _selectedCategory = widget.event['category'] ?? 'Music';
    _selectedType = widget.event['type'] ?? 'In Person';
    _existingImageUrl = widget.event['imageUrl'];

    // Parse dates
    _startDate = _parseDate(widget.event['startDate']);
    _endDate = _parseDate(widget.event['endDate']);
  }

  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null) return null;
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        return DateTime(int.parse(parts[2]), int.parse(parts[1]),
            int.parse(parts[0]));
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _venueController.dispose();
    for (final t in _tiers) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final selected = await _pickAndCropPosterImage(context);
    if (selected != null) {
      setState(() {
        _selectedImage = selected;
      });
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now().add(const Duration(days: 1)))
          : (_endDate ?? DateTime.now().add(const Duration(days: 1))),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<String?> _uploadImage(String eventId) async {
    if (_selectedImage == null) {
      return _existingImageUrl;
    }

    try {
      // Read image file and convert to base64
      final bytes = await _selectedImage!.readAsBytes();
      final base64String = base64Encode(bytes);
      final dataUrl = 'data:image/jpeg;base64,$base64String';
      print('Image converted to base64 (${bytes.length} bytes)');
      return dataUrl;
    } catch (e) {
      print('Image conversion error: $e');
      throw Exception('Failed to convert image: $e');
    }
  }

  List<double> _buildFeatureVector(double price) {
    final vector = List<double>.filled(17, 0);
    final categories = [
      'Music', 'Food & Drink', 'Arts & Culture', 'Sports',
      'Technology', 'Family', 'Health & Wellness',
      'Business', 'Comedy', 'Education',
    ];
    final types = ['In Person', 'Virtual', 'Hybrid'];

    final catIdx = categories.indexOf(_selectedCategory);
    if (catIdx >= 0) vector[catIdx] = 1;

    final typeIdx = types.indexOf(_selectedType);
    if (typeIdx >= 0) vector[10 + typeIdx] = 1;

    if (price == 0) vector[13] = 1;
    else if (price <= 50) vector[14] = 1;
    else if (price <= 100) vector[15] = 1;
    else vector[16] = 1;

    return vector;
  }

  Future<void> _updateEvent() async {
    if (_titleController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        _startDate == null ||
        _endDate == null) {
      setState(() =>
      _errorMessage = 'Please fill in all required fields.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final imageUrl = await _uploadImage(widget.eventId);

      final tiers = _collectTiers(_tiers);
      final minPrice = _minTierPrice(tiers);

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .update({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'type': _selectedType,
        'location': _locationController.text.trim(),
        'venue': _venueController.text.trim(),
        'startDate':
        '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}',
        'endDate':
        '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
        'ticketTiers': tiers,
        'ticketPrice': minPrice,
        'keywords': _selectedKeywords,
        'featureVector': _buildFeatureVector(minPrice),
        'imageUrl': imageUrl ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event updated successfully!'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Update event error: $e');
      String errorMsg = 'Failed to update. Please try again.';
      if (e.toString().contains('permission')) {
        errorMsg = 'Storage permission denied. Check Firebase rules.';
      }
      setState(() => _errorMessage = errorMsg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSelectedImage = _selectedImage != null;
    final hasExistingImage = _existingImageUrl != null &&
        (_existingImageUrl as String).isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Event',
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
            // Event Poster
            _buildLabel('Event Poster'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickImage,
              child: AspectRatio(
                aspectRatio: _posterAspectRatio,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  child: hasSelectedImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : (hasExistingImage
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              child: _buildEditEventImage(_existingImageUrl!),
                            )
                          : _buildImagePlaceholder()),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to select poster image (16:9)',
              style: const TextStyle(fontSize: 12, color: AppColors.grey500),
            ),
            const SizedBox(height: 20),

            // Title
            _buildLabel('Event Title *'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _titleController,
              hint: 'e.g. Rock the Valley Festival 2025',
              icon: Icons.title,
            ),
            const SizedBox(height: 20),

            // Description
            _buildLabel('Description'),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: _inputDecoration(
                  'Tell attendees about your event...', null),
            ),
            const SizedBox(height: 20),

            // Category
            _buildLabel('Category *'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  items: _categories.map((cat) {
                    return DropdownMenuItem(
                        value: cat, child: Text(cat));
                  }).toList(),
                  onChanged: (val) =>
                      setState(() => _selectedCategory = val!),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Type
            _buildLabel('Event Type *'),
            const SizedBox(height: 8),
            Row(
              children: _types.map((type) {
                final selected = _selectedType == type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedType = type),
                    child: Container(
                      margin: EdgeInsets.only(
                          right: type != _types.last ? 8 : 0),
                      padding:
                      const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.cardBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        type,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppColors.black
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Location
            _buildLabel('Location *'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _locationController,
              hint: 'e.g. Kuala Lumpur',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 20),

            // Venue
            _buildLabel('Venue'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _venueController,
              hint: 'e.g. Stadium Merdeka',
              icon: Icons.place_outlined,
            ),
            const SizedBox(height: 20),

            // Dates
            _buildLabel('Event Dates *'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(true),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: _startDate != null
                              ? AppColors.primary
                              : AppColors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16,
                              color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            _startDate != null
                                ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                : 'Start date',
                            style: TextStyle(
                              fontSize: 13,
                              color: _startDate != null
                                  ? AppColors.textPrimary
                                  : AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(false),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: _endDate != null
                              ? AppColors.primary
                              : AppColors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16,
                              color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            _endDate != null
                                ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                : 'End date',
                            style: TextStyle(
                              fontSize: 13,
                              color: _endDate != null
                                  ? AppColors.textPrimary
                                  : AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Ticket Categories
            _buildLabel('Ticket Categories'),
            const SizedBox(height: 4),
            const Text(
              'Add one row per seat type. Use price 0 for free entry.',
              style: TextStyle(fontSize: 12, color: AppColors.grey500),
            ),
            const SizedBox(height: 12),
            _buildTierEditor(
              tiers: _tiers,
              onAdd: () => setState(() => _tiers.add(_TierControllers())),
              onRemove: (i) => setState(() {
                _tiers.removeAt(i).dispose();
              }),
            ),
            const SizedBox(height: 20),

            // Tags
            _buildLabel('Tags'),
            const SizedBox(height: 4),
            const Text(
              'Select tags that describe your event',
              style: TextStyle(fontSize: 12, color: AppColors.grey500),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allTags.map((tag) {
                final selected = _selectedKeywords.contains(tag);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedKeywords.remove(tag);
                    } else {
                      _selectedKeywords.add(tag);
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.transparent,
                      ),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: selected ? AppColors.white : AppColors.primary,
                      ),
                    ),
                  ),
                );
              }).toList(),
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

            // Update Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.black,
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
                    color: AppColors.black,
                    strokeWidth: 2.5,
                  ),
                )
                    : const Text(
                  'Update Event',
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

  Widget _buildImagePlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              size: 50, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            'Add Event Poster',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditEventImage(String imageUrl) {
    // Check if it's a base64 data URL
    if (imageUrl.startsWith('data:image')) {
      try {
        final base64String =
            imageUrl.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildImagePlaceholder();
          },
        );
      } catch (e) {
        return _buildImagePlaceholder();
      }
    } else {
      // It's a network URL (if any)
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildImagePlaceholder();
        },
      );
    }
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

  InputDecoration _inputDecoration(String hint, IconData? icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
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
      decoration: _inputDecoration(hint, icon),
    );
  }
}