import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nscgschedule/friends_service.dart';
import 'package:nscgschedule/models/friend_models.dart';
import 'package:nscgschedule/models/timetable_models.dart' as models;
import 'package:nscgschedule/settings.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';

/// Screen for sharing your timetable via QR code
class ShareQRScreen extends StatefulWidget {
  const ShareQRScreen({super.key});

  @override
  State<ShareQRScreen> createState() => _ShareQRScreenState();
}

class _ShareQRScreenState extends State<ShareQRScreen> {
  final FriendsService _friendsService = GetIt.I<FriendsService>();
  final Settings _settings = GetIt.I<Settings>();
  PrivacyLevel _selectedPrivacy = PrivacyLevel.busyBlocks;
  String? _qrData;
  bool _isLoading = true;
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey _qrKey = GlobalKey();
  int _genToken = 0;
  bool _isGenerating = false;
  bool _needsRegenerate = false;

  @override
  void initState() {
    super.initState();
    _loadDefaultsAndGenerate();
  }

  Future<void> _loadDefaultsAndGenerate() async {
    final owner = await _settings.getKey('timetableOwner');
    if (owner.isNotEmpty) {
      _nameController.text = owner;
    } else {
      _nameController.text = 'My Schedule';
    }
    await _generateQR(forceLoading: true);
  }

  Future<void> _generateQR({bool forceLoading = false}) async {
    // If a generation is already in progress, mark that we need a refresh
    // and return; when the in-progress generation finishes it will run
    // another generation if needed. This prevents overlapping reloads.
    if (_isGenerating) {
      _needsRegenerate = true;
      return;
    }

    _isGenerating = true;
    final int myToken = ++_genToken;
    if (forceLoading && mounted) setState(() => _isLoading = true);

    try {
      // Get user's name (editable field; prefills from saved timetable owner)
      final userName = _nameController.text.trim().isEmpty
          ? 'My Schedule'
          : _nameController.text.trim();

      // Persist the chosen share name so it's used as the default next time
      final normalizedUserName = userName
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      await _settings.setKey('timetableOwner', normalizedUserName);

      // Get user's timetable
      final timetableMap = await _settings.getMap('timetable');
      if (timetableMap.isEmpty) {
        if (myToken == _genToken && forceLoading && mounted) {
          setState(() => _isLoading = false);
        }
        _isGenerating = false;
        if (_needsRegenerate) {
          _needsRegenerate = false;
          await _generateQR(forceLoading: forceLoading);
        }
        return;
      }

      final timetable = models.Timetable.fromJson(
        Map<String, dynamic>.from(timetableMap),
      );

      // Generate QR data
      final ownerId = await _settings.getKey('timetableOwnerId');
      final qrData = _friendsService.generateQRData(
        userName: normalizedUserName,
        timetable: timetable,
        privacyLevel: _selectedPrivacy,
        userId: ownerId.isNotEmpty ? ownerId : null,
      );
      if (myToken == _genToken && mounted) {
        setState(() {
          _qrData = qrData;
          if (forceLoading) _isLoading = false;
        });
      }
      _isGenerating = false;
      if (_needsRegenerate) {
        _needsRegenerate = false;
        // Fire another generation to pick up the latest input
        await _generateQR(forceLoading: false);
      }
    } catch (e) {
      if (myToken == _genToken && mounted) {
        if (forceLoading) setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating QR: $e')));
      }
      _isGenerating = false;
      if (_needsRegenerate) {
        _needsRegenerate = false;
        await _generateQR(forceLoading: false);
      }
    }
  }

  Future<void> _saveQrImage() async {
    if (_qrData == null) return;

    // Generate PNG into a temporary file and share it (no persistent save)

    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        Fluttertoast.showToast(msg: 'Could not capture QR image');
        return;
      }
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        Fluttertoast.showToast(msg: 'Failed to encode image');
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final file = File(
        p.join(
          tempDir.path,
          'nscg_qr_${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      );
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

      // Offer share immediately
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'image/png')],
            text: 'Timetable QR Code',
          ),
        );
        if (mounted) Fluttertoast.showToast(msg: 'Shared image');
      } catch (e) {
        if (mounted) Fluttertoast.showToast(msg: 'Error sharing image: $e');
      }
    } catch (e) {
      if (mounted) Fluttertoast.showToast(msg: 'Error saving QR image: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share Your Schedule')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Share with Friends',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Let others scan this QR code to add your schedule',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_qrData != null)
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: RepaintBoundary(
                            key: _qrKey,
                            child: QrImageView(
                              data: _qrData!,
                              version: QrVersions.auto,
                              size: 280,
                              backgroundColor: Colors.white,
                              errorCorrectionLevel: QrErrorCorrectLevel.L,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _qrData == null ? null : _saveQrImage,
                              icon: const Icon(Icons.share),
                              label: const Text('Share QR Code Image'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Your name for this share',
                      hintText: 'e.g. John Doe',
                    ),
                    onChanged: (v) => _generateQR(),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Privacy Level',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          RadioGroup<PrivacyLevel>(
                            groupValue: _selectedPrivacy,
                            onChanged: (PrivacyLevel? v) {
                              if (v == null) return;
                              setState(() => _selectedPrivacy = v);
                              _generateQR();
                            },
                            child: Column(
                              children: [
                                _buildPrivacyOption(
                                  PrivacyLevel.freeTimeOnly,
                                  'Free Time Only',
                                  'Only shows when you are available',
                                  Icons.lock,
                                ),
                                const Divider(),
                                _buildPrivacyOption(
                                  PrivacyLevel.busyBlocks,
                                  'Busy Blocks',
                                  'Shows class times but hides details',
                                  Icons.lock_open,
                                ),
                                const Divider(),
                                _buildPrivacyOption(
                                  PrivacyLevel.fullDetails,
                                  'Full Details',
                                  'Shares subjects, rooms, and times',
                                  Icons.visibility,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildInfoCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildPrivacyOption(
    PrivacyLevel level,
    String title,
    String description,
    IconData icon,
  ) {
    final isSelected = _selectedPrivacy == level;
    return RadioListTile<PrivacyLevel>(
      value: level,
      title: Row(
        children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(title)],
      ),
      subtitle: Text(description),
      selected: isSelected,
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'This QR code is generated locally and doesn\'t store any data online. Your schedule stays on your device.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Screen for scanning a friend's QR code
class ScanQRScreen extends StatefulWidget {
  const ScanQRScreen({super.key});

  @override
  State<ScanQRScreen> createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends State<ScanQRScreen> {
  final FriendsService _friendsService = GetIt.I<FriendsService>();
  MobileScannerController? _controller;
  bool _isProcessing = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
    // Request camera permission proactively for a smoother UX
    () async {
      try {
        final status = await Permission.camera.status;
        if (!status.isGranted) await Permission.camera.request();
      } catch (_) {}
    }();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() => _isProcessing = true);

    try {
      final friend = _friendsService.parseQRData(barcode.rawValue!);

      if (friend == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Invalid QR code')));
        }
        setState(() => _isProcessing = false);
        return;
      }

      // Use scanned friend's name as-is; user can rename later from profile/menu.
      var friendToSave = friend;

      // Auto-replace by stable userId when available
      if (friendToSave.userId != null && friendToSave.userId!.isNotEmpty) {
        final matches = _friendsService
            .getAllFriends()
            .where((f) => f.userId != null && f.userId == friendToSave.userId)
            .toList();
        if (matches.isNotEmpty) {
          final existingByUserId = matches.first;
          // Preserve any locally-set profile picture when replacing the entry
          final replaced = friendToSave.copyWith(
            id: existingByUserId.id,
            addedAt: DateTime.now(),
            profilePicPath: existingByUserId.profilePicPath,
          );
          await _friendsService.saveFriend(replaced);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${replaced.name} (updated)')),
            );
            context.pop();
            return;
          }
        }
      }

      // Check exact share id collision as a fallback
      final existing = _friendsService.getFriend(friend.id);
      if (existing != null) {
        if (mounted) {
          final replace = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Friend Already Added'),
              content: Text(
                '${friend.name} is already in your friends list. Replace with updated data?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Replace'),
                ),
              ],
            ),
          );

          if (replace != true) {
            setState(() => _isProcessing = false);
            return;
          }
          // Preserve locally-set profile picture when replacing by share id
          final preserved = friendToSave.copyWith(
            id: existing.id,
            addedAt: DateTime.now(),
            profilePicPath: existing.profilePicPath,
          );
          // Use preserved as the object to save below
          friendToSave = preserved;
        }
      }
      // Save friend (use edited name version)
      await _friendsService.saveFriend(friendToSave);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${friendToSave.name} added successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _scanFromImage() async {
    if (_isProcessing) return;
    // Ensure permission to read images
    if (!await _ensureImagePermissionForScan()) return;
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      setState(() => _isProcessing = true);

      final dynamic result = await _controller?.analyzeImage(file.path);

      // Handle various possible return types from analyzeImage across versions
      List<Barcode>? barcodes;
      if (result == null) {
        barcodes = null;
      } else if (result is BarcodeCapture) {
        barcodes = result.barcodes;
      } else if (result is List) {
        // some versions return a list of barcodes
        barcodes = List<Barcode>.from(result.whereType<Barcode>());
      } else if (result is Barcode) {
        barcodes = [result];
      }

      if (barcodes == null || barcodes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No QR code found in image')),
          );
        }
        setState(() => _isProcessing = false);
        return;
      }

      // Use first barcode found
      final barcode = barcodes.first;
      final raw = barcode.rawValue;
      if (raw == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No QR code found in image')),
          );
        }
        setState(() => _isProcessing = false);
        return;
      }

      // Reuse existing handler logic by wrapping into a fake BarcodeCapture-like flow
      // But simpler: parse directly like the camera flow
      final friend = _friendsService.parseQRData(raw);
      if (friend == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Invalid QR code')));
        }
        setState(() => _isProcessing = false);
        return;
      }

      // Save friend (preserve existing logic from camera flow)
      var friendToSave = friend;
      if (friendToSave.userId != null && friendToSave.userId!.isNotEmpty) {
        final matches = _friendsService
            .getAllFriends()
            .where((f) => f.userId != null && f.userId == friendToSave.userId)
            .toList();
        if (matches.isNotEmpty) {
          final existingByUserId = matches.first;
          final replaced = friendToSave.copyWith(
            id: existingByUserId.id,
            addedAt: DateTime.now(),
            profilePicPath: existingByUserId.profilePicPath,
          );
          await _friendsService.saveFriend(replaced);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${replaced.name} (updated)')),
            );
            context.pop();
            return;
          }
        }
      }

      final existing = _friendsService.getFriend(friend.id);
      if (existing != null) {
        if (mounted) {
          final replace = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Friend Already Added'),
              content: Text(
                '${friend.name} is already in your friends list. Replace with updated data?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Replace'),
                ),
              ],
            ),
          );

          if (replace != true) {
            setState(() => _isProcessing = false);
            return;
          }
          final preserved = friendToSave.copyWith(
            id: existing.id,
            addedAt: DateTime.now(),
            profilePicPath: existing.profilePicPath,
          );
          friendToSave = preserved;
        }
      }

      await _friendsService.saveFriend(friendToSave);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${friendToSave.name} added successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error scanning image: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<bool> _ensureImagePermissionForScan() async {
    try {
      if (Platform.isAndroid) {
        final photos = await Permission.photos.status;
        if (photos.isGranted) return true;
        final req = await Permission.photos.request();
        if (req.isGranted) return true;
        final storage = await Permission.storage.request();
        if (storage.isGranted) return true;
        if (storage.isPermanentlyDenied && context.mounted ||
            req.isPermanentlyDenied && context.mounted) {
          final open = await showDialog<bool>(
            // ignore: use_build_context_synchronously
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Permission required'),
              content: const Text(
                'Please grant photo permission in app settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
          if (open == true) await openAppSettings();
        }
        return false;
      } else if (Platform.isIOS) {
        final photos = await Permission.photos.status;
        if (photos.isGranted) return true;
        final req = await Permission.photos.request();
        if (req.isGranted) return true;
        if (req.isPermanentlyDenied && context.mounted) {
          final open = await showDialog<bool>(
            // ignore: use_build_context_synchronously
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Permission required'),
              content: const Text('Please grant photo permission in Settings.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
          if (open == true) await openAppSettings();
        }
        return false;
      }
    } catch (_) {
      final s = await Permission.storage.request();
      return s.isGranted;
    }
    return true;
  }

  // Removed interactive naming prompt: renaming is available via friend profile/menu.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Friend QR')),
      body: Stack(
        children: [
          if (_controller != null)
            MobileScanner(controller: _controller!, onDetect: _handleBarcode),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 4, right: 8),
                        child: Icon(
                          Icons.qr_code_scanner,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Position the QR code within the frame',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'It will scan the code automatically',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _scanFromImage,
                    icon: const Icon(Icons.photo_library, size: 18),
                    label: const Text('Select from library'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
