/// Prescription upload widget for pharmacy checkout
///
/// Allows the user to pick an image from camera or gallery,
/// preview it, and returns a base64-encoded image string.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';

class PrescriptionUpload extends StatefulWidget {
  final ValueChanged<String?> onChanged;
  final String? initialImage;

  const PrescriptionUpload({
    super.key,
    required this.onChanged,
    this.initialImage,
  });

  @override
  State<PrescriptionUpload> createState() => _PrescriptionUploadState();
}

class _PrescriptionUploadState extends State<PrescriptionUpload> {
  String? _base64Image;
  File? _imageFile;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialImage != null) {
      _base64Image = widget.initialImage;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile == null) return;

      setState(() => _isProcessing = true);

      final file = File(pickedFile.path);
      final bytes = await file.readAsBytes();
      final base64Str = base64Encode(bytes);

      setState(() {
        _imageFile = file;
        _base64Image = base64Str;
        _isProcessing = false;
      });

      widget.onChanged(base64Str);
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: const Color(AppConfig.ERROR_COLOR),
          ),
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _imageFile = null;
      _base64Image = null;
    });
    widget.onChanged(null);
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConfig.RADIUS_XL),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppConfig.SPACING_LG,
            horizontal: AppConfig.SPACING_MD,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(AppConfig.DIVIDER_COLOR),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Upload Prescription',
                style: TextStyle(
                  fontSize: AppConfig.FONT_SIZE_XLARGE,
                  fontWeight: FontWeight.w700,
                  color: Color(AppConfig.TEXT_PRIMARY),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _SourceOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SourceOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _base64Image != null;

    return Container(
      padding: const EdgeInsets.all(AppConfig.SPACING_MD),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
        border: Border.all(
          color: hasImage
              ? const Color(AppConfig.SUCCESS_COLOR).withValues(alpha: 0.4)
              : const Color(AppConfig.DIVIDER_COLOR),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 20,
                color: const Color(AppConfig.PRIMARY_COLOR),
              ),
              const SizedBox(width: 8),
              const Text(
                'Upload Prescription',
                style: TextStyle(
                  fontSize: AppConfig.FONT_SIZE_LARGE,
                  fontWeight: FontWeight.w700,
                  color: Color(AppConfig.TEXT_PRIMARY),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(AppConfig.ERROR_COLOR).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppConfig.RADIUS_SM),
                ),
                child: const Text(
                  'Required',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(AppConfig.ERROR_COLOR),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Image preview or placeholder
          if (_isProcessing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: Color(AppConfig.PRIMARY_COLOR),
                ),
              ),
            )
          else if (hasImage)
            _buildImagePreview()
          else
            _buildPlaceholder(),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
          child: _imageFile != null
              ? Image.file(
                  _imageFile!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
              : _base64Image != null
                  ? Image.memory(
                      base64Decode(_base64Image!),
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
        ),
        // Remove button
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: _removeImage,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
        // Success indicator
        Positioned(
          bottom: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(AppConfig.SUCCESS_COLOR),
              borderRadius: BorderRadius.circular(AppConfig.RADIUS_SM),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_rounded, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  'Uploaded',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return GestureDetector(
      onTap: _showImageSourceDialog,
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(AppConfig.BACKGROUND_COLOR),
          borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
          border: Border.all(
            color: const Color(AppConfig.DIVIDER_COLOR),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(AppConfig.PRIMARY_COLOR).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_a_photo_rounded,
                size: 28,
                color: Color(AppConfig.PRIMARY_COLOR),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tap to upload prescription',
              style: TextStyle(
                fontSize: AppConfig.FONT_SIZE_MEDIUM,
                fontWeight: FontWeight.w600,
                color: Color(AppConfig.TEXT_SECONDARY),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Take a photo or choose from gallery',
              style: TextStyle(
                fontSize: AppConfig.FONT_SIZE_SMALL,
                color: Color(AppConfig.TEXT_HINT),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(AppConfig.BACKGROUND_COLOR),
          borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: const Color(AppConfig.PRIMARY_COLOR)),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: AppConfig.FONT_SIZE_MEDIUM,
                fontWeight: FontWeight.w600,
                color: Color(AppConfig.TEXT_PRIMARY),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
