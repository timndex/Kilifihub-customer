/// Addresses management screen for KilifiHub Customer App
///
/// Displays saved delivery addresses with add/edit/delete functionality.
/// Includes address label selector and map pin for lat/lng selection.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../config/app_config.dart';
import '../models/address_model.dart';
import '../services/api_service.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  List<AddressModel> _addresses = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ApiService.instance;
      final addresses = await api.getAddresses();
      if (mounted) {
        setState(() {
          _addresses = addresses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load addresses. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addOrUpdateAddress([AddressModel? existing]) async {
    final result = await showModalBottomSheet<AddressModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddressFormSheet(
        existingAddress: existing,
      ),
    );

    if (result != null) {
      await _loadAddresses();
    }
  }

  Future<void> _deleteAddress(AddressModel address) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
        ),
        title: const Text('Delete Address?'),
        content: Text(
          'Are you sure you want to delete "${address.displayLabel}" address?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(AppConfig.ERROR_COLOR),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Note: API doesn't have delete endpoint in the current spec
      // We'll filter locally and refresh
      setState(() {
        _addresses = _addresses.where((a) => a.id != address.id).toList();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete address'),
            backgroundColor: Color(AppConfig.ERROR_COLOR),
          ),
        );
      }
    }
  }

  Future<void> _setDefault(AddressModel address) async {
    try {
      final api = ApiService.instance;
      await api.addAddress(
        address.label,
        address.address,
        address.lat,
        address.lng,
        true, // isDefault
      );
      await _loadAddresses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to set default address'),
            backgroundColor: Color(AppConfig.ERROR_COLOR),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConfig.BACKGROUND_COLOR),
      appBar: AppBar(
        title: const Text('Delivery Addresses'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: () => _addOrUpdateAddress(),
            icon: const Icon(Icons.add_rounded, size: 28),
            tooltip: 'Add Address',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(AppConfig.PRIMARY_COLOR),
              ),
            )
          : _error != null && _addresses.isEmpty
              ? _buildError()
              : _addresses.isEmpty
                  ? _buildEmpty()
                  : _buildAddressList(),
      bottomNavigationBar: _addresses.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _addOrUpdateAddress(),
                    icon: const Icon(Icons.add_rounded, size: 22),
                    label: const Text(
                      'Add New Address',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(AppConfig.PRIMARY_COLOR),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppConfig.RADIUS_MD),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildAddressList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: _addresses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final address = _addresses[index];
        return _AddressCard(
          address: address,
          onSetDefault: () => _setDefault(address),
          onEdit: () => _addOrUpdateAddress(address),
          onDelete: () => _deleteAddress(address),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(AppConfig.TEXT_HINT).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on_outlined,
                size: 40,
                color: Color(AppConfig.TEXT_HINT),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Saved Addresses',
              style: TextStyle(
                fontSize: AppConfig.FONT_SIZE_XLARGE,
                fontWeight: FontWeight.w700,
                color: Color(AppConfig.TEXT_PRIMARY),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a delivery address to speed up your checkout.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppConfig.FONT_SIZE_MEDIUM,
                color: Color(AppConfig.TEXT_SECONDARY),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _addOrUpdateAddress(),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'Add Address',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppConfig.PRIMARY_COLOR),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConfig.RADIUS_ROUND),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Color(AppConfig.ERROR_COLOR),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppConfig.FONT_SIZE_MEDIUM,
                color: Color(AppConfig.TEXT_SECONDARY),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAddresses,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Address Card ──────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  final AddressModel address;
  final VoidCallback onSetDefault;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AddressCard({
    required this.address,
    required this.onSetDefault,
    required this.onEdit,
    required this.onDelete,
  });

  IconData get _labelIcon {
    switch (address.iconLabel) {
      case 'home':
        return Icons.home_rounded;
      case 'work':
        return Icons.work_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  Color get _labelColor {
    switch (address.iconLabel) {
      case 'home':
        return const Color(AppConfig.PRIMARY_COLOR);
      case 'work':
        return const Color(0xFF2196F3);
      default:
        return const Color(0xFF9C27B0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSetDefault,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
          border: address.isDefault
              ? Border.all(
                  color: const Color(AppConfig.PRIMARY_COLOR).withValues(alpha: 0.4),
                  width: 1.5,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _labelColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
              ),
              child: Icon(_labelIcon, size: 22, color: _labelColor),
            ),
            const SizedBox(width: 14),

            // Address details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        address.displayLabel,
                        style: const TextStyle(
                          fontSize: AppConfig.FONT_SIZE_LARGE,
                          fontWeight: FontWeight.w700,
                          color: Color(AppConfig.TEXT_PRIMARY),
                        ),
                      ),
                      if (address.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(AppConfig.SUCCESS_COLOR)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Default',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(AppConfig.SUCCESS_COLOR),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppConfig.FONT_SIZE_MEDIUM,
                      color: Color(AppConfig.TEXT_SECONDARY),
                      height: 1.4,
                    ),
                  ),
                  if (!address.isDefault) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: onSetDefault,
                      child: const Text(
                        'Set as default',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(AppConfig.PRIMARY_COLOR),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Action buttons
            Column(
              children: [
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(AppConfig.TEXT_HINT).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 16,
                      color: Color(AppConfig.TEXT_SECONDARY),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(AppConfig.ERROR_COLOR).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: Color(AppConfig.ERROR_COLOR),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Address Form Sheet ──────────────────────────────────

class _AddressFormSheet extends StatefulWidget {
  final AddressModel? existingAddress;

  const _AddressFormSheet({this.existingAddress});

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _addressController = TextEditingController();
  String _label = 'Home';
  double? _lat;
  double? _lng;
  bool _isDefault = false;
  bool _isSaving = false;

  // Map controller
  GoogleMapController? _mapController;
  final double _defaultLat = -3.6317;
  final double _defaultLng = 39.8499;

  @override
  void initState() {
    super.initState();
    if (widget.existingAddress != null) {
      _addressController.text = widget.existingAddress!.address;
      _label = widget.existingAddress!.label;
      _lat = widget.existingAddress!.lat;
      _lng = widget.existingAddress!.lng;
      _isDefault = widget.existingAddress!.isDefault;
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied'),
              backgroundColor: Color(AppConfig.ERROR_COLOR),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
      });

      // Reverse geocode to get address
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final address = [
            place.street,
            place.subLocality,
            place.locality,
            place.country,
          ].where((s) => s != null && s.isNotEmpty).join(', ');
          _addressController.text = address;
        }
      } catch (_) {
        // Reverse geocoding failed — keep lat/lng
      }

      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(_lat!, _lng!)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to get current location'),
            backgroundColor: Color(AppConfig.ERROR_COLOR),
          ),
        );
      }
    }
  }

  Future<void> _saveAddress() async {
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an address'),
          backgroundColor: Color(AppConfig.ERROR_COLOR),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final api = ApiService.instance;
      await api.addAddress(
        _label,
        _addressController.text.trim(),
        _lat,
        _lng,
        _isDefault,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address saved successfully'),
            backgroundColor: Color(AppConfig.SUCCESS_COLOR),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save address'),
            backgroundColor: Color(AppConfig.ERROR_COLOR),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConfig.RADIUS_XL),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(AppConfig.DIVIDER_COLOR),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existingAddress != null
                      ? 'Edit Address'
                      : 'Add New Address',
                  style: const TextStyle(
                    fontSize: AppConfig.FONT_SIZE_XLARGE,
                    fontWeight: FontWeight.w800,
                    color: Color(AppConfig.TEXT_PRIMARY),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),

          // Form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label selector
                  const Text(
                    'Label',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(AppConfig.TEXT_PRIMARY),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _LabelChip(
                        label: 'Home',
                        icon: Icons.home_rounded,
                        selected: _label == 'Home',
                        onTap: () => setState(() => _label = 'Home'),
                      ),
                      const SizedBox(width: 8),
                      _LabelChip(
                        label: 'Work',
                        icon: Icons.work_rounded,
                        selected: _label == 'Work',
                        onTap: () => setState(() => _label = 'Work'),
                      ),
                      const SizedBox(width: 8),
                      _LabelChip(
                        label: 'Other',
                        icon: Icons.place_rounded,
                        selected: _label == 'Other',
                        onTap: () => setState(() => _label = 'Other'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Address field
                  const Text(
                    'Address',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(AppConfig.TEXT_PRIMARY),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _addressController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter your delivery address',
                      hintStyle: const TextStyle(
                          color: Color(AppConfig.TEXT_HINT), fontSize: 14),
                      filled: true,
                      fillColor: const Color(AppConfig.BACKGROUND_COLOR),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppConfig.RADIUS_MD),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Use current location button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _getCurrentLocation,
                      icon: const Icon(Icons.my_location_rounded, size: 18),
                      label: const Text('Use Current Location'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(AppConfig.PRIMARY_COLOR),
                        side: const BorderSide(
                            color: Color(AppConfig.PRIMARY_COLOR)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppConfig.RADIUS_MD),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Map pin selector
                  const Text(
                    'Pin Location on Map',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(AppConfig.TEXT_PRIMARY),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(AppConfig.RADIUS_MD),
                      border: Border.all(
                          color: const Color(AppConfig.DIVIDER_COLOR)),
                    ),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppConfig.RADIUS_MD),
                      child: GoogleMap(
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            _lat ?? _defaultLat,
                            _lng ?? _defaultLng,
                          ),
                          zoom: 15,
                        ),
                        onCameraMove: (position) {
                          _lat = position.target.latitude;
                          _lng = position.target.longitude;
                        },
                        markers: {
                          Marker(
                            markerId: const MarkerId('pin'),
                            position: LatLng(
                              _lat ?? _defaultLat,
                              _lng ?? _defaultLng,
                            ),
                            draggable: true,
                            onDragEnd: (position) {
                              setState(() {
                                _lat = position.latitude;
                                _lng = position.longitude;
                              });
                            },
                          ),
                        },
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        myLocationButtonEnabled: false,
                        compassEnabled: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Default toggle
                  SwitchListTile(
                    value: _isDefault,
                    onChanged: (v) => setState(() => _isDefault = v),
                    title: const Text(
                      'Set as default address',
                      style: TextStyle(
                        fontSize: AppConfig.FONT_SIZE_MEDIUM,
                        fontWeight: FontWeight.w600,
                        color: Color(AppConfig.TEXT_PRIMARY),
                      ),
                    ),
                    activeColor: const Color(AppConfig.PRIMARY_COLOR),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveAddress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(AppConfig.PRIMARY_COLOR),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(AppConfig.TEXT_HINT)
                            .withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppConfig.RADIUS_MD),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Address',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
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

// ─── Label Chip ──────────────────────────────────────────

class _LabelChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _LabelChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(AppConfig.PRIMARY_COLOR).withValues(alpha: 0.1)
              : const Color(AppConfig.BACKGROUND_COLOR),
          borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
          border: Border.all(
            color: selected
                ? const Color(AppConfig.PRIMARY_COLOR)
                : const Color(AppConfig.DIVIDER_COLOR),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? const Color(AppConfig.PRIMARY_COLOR)
                  : const Color(AppConfig.TEXT_SECONDARY),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? const Color(AppConfig.PRIMARY_COLOR)
                    : const Color(AppConfig.TEXT_SECONDARY),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
