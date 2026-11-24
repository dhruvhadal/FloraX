import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/app_activity_logger.dart';

/// Geolocation and acquisition lifecycle status
enum LocationStatus {
  initial,
  loading,
  ready,
  serviceDisabled,
  permissionDenied,
  deniedForever,
  error,
}

/// Immutable verified farmer location model with reverse-geocoded spatial attributes
@immutable
class FarmerLocation {
  final double latitude;
  final double longitude;
  final String village;
  final String district;
  final String state;
  final String postalCode;
  final bool isOfflineCoordinatesOnly;
  final String reverseGeocodeSource;
  final DateTime updatedAt;

  const FarmerLocation({
    required this.latitude,
    required this.longitude,
    required this.village,
    required this.district,
    required this.state,
    required this.postalCode,
    this.isOfflineCoordinatesOnly = false,
    this.reverseGeocodeSource = 'geocoding_placemark',
    required this.updatedAt,
  });

  /// Display string for app bar, status pills, and dashboard cards
  String get displayLocation {
    if (isOfflineCoordinatesOnly || (village.isEmpty && district.isEmpty)) {
      final latDirection = latitude >= 0 ? 'N' : 'S';
      final lonDirection = longitude >= 0 ? 'E' : 'W';
      return '${latitude.abs().toStringAsFixed(4)}° $latDirection, ${longitude.abs().toStringAsFixed(4)}° $lonDirection • Offline GPS';
    }

    if (village.isNotEmpty && district.isNotEmpty) {
      return '$village, $district';
    }
    if (district.isNotEmpty && state.isNotEmpty) {
      return '$district, $state';
    }
    if (district.isNotEmpty) {
      return district;
    }
    if (village.isNotEmpty) {
      return village;
    }
    return state.isNotEmpty ? state : 'Detected Location';
  }

  /// Full concatenated postal address string
  String get fullAddress {
    final parts = [village, district, state, postalCode]
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return displayLocation;
    }
    return parts.join(', ');
  }

  Map<String, dynamic> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
    'village': village,
    'district': district,
    'state': state,
    'postalCode': postalCode,
    'isOfflineCoordinatesOnly': isOfflineCoordinatesOnly,
    'reverseGeocodeSource': reverseGeocodeSource,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory FarmerLocation.fromMap(Map<String, dynamic> map) {
    return FarmerLocation(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      village: map['village']?.toString() ?? '',
      district: map['district']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
      postalCode: map['postalCode']?.toString() ?? '',
      isOfflineCoordinatesOnly: map['isOfflineCoordinatesOnly'] as bool? ?? false,
      reverseGeocodeSource: map['reverseGeocodeSource']?.toString() ?? 'cached',
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory FarmerLocation.fromJson(String source) =>
      FarmerLocation.fromMap(jsonDecode(source) as Map<String, dynamic>);

  FarmerLocation copyWith({
    double? latitude,
    double? longitude,
    String? village,
    String? district,
    String? state,
    String? postalCode,
    bool? isOfflineCoordinatesOnly,
    String? reverseGeocodeSource,
    DateTime? updatedAt,
  }) {
    return FarmerLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      village: village ?? this.village,
      district: district ?? this.district,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      isOfflineCoordinatesOnly: isOfflineCoordinatesOnly ?? this.isOfflineCoordinatesOnly,
      reverseGeocodeSource: reverseGeocodeSource ?? this.reverseGeocodeSource,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FarmerLocation &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          village == other.village &&
          district == other.district &&
          state == other.state &&
          postalCode == other.postalCode;

  @override
  int get hashCode =>
      latitude.hashCode ^
      longitude.hashCode ^
      village.hashCode ^
      district.hashCode ^
      state.hashCode ^
      postalCode.hashCode;
}

/// Reactive State for Location Provider
@immutable
class LocationState {
  final LocationStatus status;
  final FarmerLocation? location;
  final String? errorMessage;

  const LocationState({
    this.status = LocationStatus.initial,
    this.location,
    this.errorMessage,
  });

  bool get isLoading => status == LocationStatus.loading;
  bool get isReady => status == LocationStatus.ready && location != null;
  bool get isServiceDisabled => status == LocationStatus.serviceDisabled;
  bool get isPermissionDenied => status == LocationStatus.permissionDenied;
  bool get isDeniedForever => status == LocationStatus.deniedForever;

  LocationState copyWith({
    LocationStatus? status,
    FarmerLocation? location,
    String? errorMessage,
  }) {
    return LocationState(
      status: status ?? this.status,
      location: location ?? this.location,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Production Location Service with 3-Tier Reverse Geocoding & Android Resilience
class LocationService {
  final http.Client _httpClient;

  static const String cacheKey = 'florax_verified_farmer_location';

  LocationService({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  /// Calculates distance in kilometers between two coordinates using Haversine formula
  static double calculateDistanceKm(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    final distanceMeters = Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    );
    return distanceMeters / 1000.0;
  }

  /// Open Android system location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open application permission settings
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Load cached location from local persistent storage
  Future<FarmerLocation?> getCachedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString(cacheKey);
      if (cachedStr != null && cachedStr.isNotEmpty) {
        return FarmerLocation.fromJson(cachedStr);
      }
    } catch (e) {
      debugPrint('[LocationService] Failed to read cached location: $e');
    }
    return null;
  }

  /// Cache location to SharedPreferences
  Future<void> saveCachedLocation(FarmerLocation location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, location.toJson());
    } catch (e) {
      debugPrint('[LocationService] Failed to save location cache: $e');
    }
  }

  /// Syncs acquired location to farmer profile in Firestore
  Future<void> syncLocationToFirestore(
    FarmerLocation loc, {
    String? farmerMobile,
  }) async {
    if (farmerMobile == null || farmerMobile.trim().isEmpty) return;

    try {
      final docRef = FirebaseFirestore.instance.collection('farmers').doc(farmerMobile.trim());
      await docRef.set({
        if (loc.village.isNotEmpty) 'village': loc.village,
        if (loc.district.isNotEmpty) 'district': loc.district,
        if (loc.state.isNotEmpty) 'state': loc.state,
        if (loc.postalCode.isNotEmpty) 'pincode': loc.postalCode,
        'lastKnownLatitude': loc.latitude,
        'lastKnownLongitude': loc.longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[LocationService] Synced live GPS to Firestore for $farmerMobile');
    } catch (e) {
      debugPrint('[LocationService] Firestore location sync deferred: $e');
    }
  }

  /// Android-Safe Coordinate Acquisition:
  /// High accuracy (12s) -> Medium accuracy (8s) -> Last known position
  Future<Position?> acquireRawPosition() async {
    // 1. High Accuracy GPS (outdoor satellite fix)
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
    } catch (e) {
      debugPrint('[LocationService] High accuracy GPS timed out or failed: $e. Falling back to medium accuracy.');
    }

    // 2. Medium Accuracy Triangulation (cell tower / Wi-Fi)
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (e) {
      debugPrint('[LocationService] Medium accuracy GPS timed out: $e. Falling back to last known position.');
    }

    // 3. Last Known Position
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      debugPrint('[LocationService] Last known position retrieval failed: $e');
      return null;
    }
  }

  /// 3-Tier Reverse Geocoding Pipeline
  /// Tier A: placemarkFromCoordinates (package:geocoding)
  /// Tier B: OpenStreetMap Nominatim reverse API (OEM / PlatformException fallback)
  /// Tier C: Offline coordinates display (No network fallback)
  Future<FarmerLocation> reverseGeocode(double lat, double lng) async {
    // -------------------------------------------------------------------------
    // TIER A: Native Geocoder via package:geocoding
    // -------------------------------------------------------------------------
    try {
      final placemarks = await Geocoding()
          .placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 6));

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final village = (p.subLocality != null && p.subLocality!.trim().isNotEmpty)
            ? p.subLocality!.trim()
            : ((p.locality != null && p.locality!.trim().isNotEmpty) ? p.locality!.trim() : '');
        final district = (p.subAdministrativeArea != null && p.subAdministrativeArea!.trim().isNotEmpty)
            ? p.subAdministrativeArea!.trim()
            : ((p.locality != null && p.locality!.trim().isNotEmpty) ? p.locality!.trim() : '');
        final state = p.administrativeArea?.trim() ?? '';
        final pin = p.postalCode?.trim() ?? '';

        if (village.isNotEmpty || district.isNotEmpty || state.isNotEmpty) {
          return FarmerLocation(
            latitude: lat,
            longitude: lng,
            village: village,
            district: district,
            state: state,
            postalCode: pin,
            isOfflineCoordinatesOnly: false,
            reverseGeocodeSource: 'geocoding_placemark',
            updatedAt: DateTime.now(),
          );
        }
      }
    } catch (e) {
      debugPrint('[LocationService] Tier A Native Geocoding failed: $e. Attempting Tier B (Nominatim).');
    }

    // -------------------------------------------------------------------------
    // TIER B: OpenStreetMap Nominatim Reverse API (HTTP Fallback)
    // -------------------------------------------------------------------------
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&accept-language=en',
      );
      final response = await _httpClient.get(
        uri,
        headers: {
          'User-Agent': 'KisanSetu/1.0 (Agronomic Crop Protection Assistant)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>? ?? {};

        final village = address['village']?.toString().trim() ??
            address['town']?.toString().trim() ??
            address['suburb']?.toString().trim() ??
            address['city']?.toString().trim() ??
            address['hamlet']?.toString().trim() ??
            '';
        final district = address['state_district']?.toString().trim() ??
            address['county']?.toString().trim() ??
            address['district']?.toString().trim() ??
            '';
        final state = address['state']?.toString().trim() ?? '';
        final pin = address['postcode']?.toString().trim() ?? '';

        if (village.isNotEmpty || district.isNotEmpty || state.isNotEmpty) {
          return FarmerLocation(
            latitude: lat,
            longitude: lng,
            village: village,
            district: district,
            state: state,
            postalCode: pin,
            isOfflineCoordinatesOnly: false,
            reverseGeocodeSource: 'osm_nominatim',
            updatedAt: DateTime.now(),
          );
        }
      }
    } catch (e) {
      debugPrint('[LocationService] Tier B Nominatim Geocoding failed: $e. Falling back to Tier C.');
    }

    // -------------------------------------------------------------------------
    // TIER C: Offline Fallback (Exact Lat/Lng representation)
    // -------------------------------------------------------------------------
    return FarmerLocation(
      latitude: lat,
      longitude: lng,
      village: '',
      district: '',
      state: '',
      postalCode: '',
      isOfflineCoordinatesOnly: true,
      reverseGeocodeSource: 'offline_coordinates',
      updatedAt: DateTime.now(),
    );
  }
}

/// StateNotifier orchestrating reactive location state throughout the app
class LocationNotifier extends StateNotifier<LocationState> {
  final LocationService _service;

  LocationNotifier(this._service) : super(const LocationState()) {
    _initFromCache();
  }

  Future<void> _initFromCache() async {
    final cached = await _service.getCachedLocation();
    if (cached != null && state.location == null) {
      state = state.copyWith(
        status: LocationStatus.ready,
        location: cached,
      );
    }
  }

  /// Triggers full GPS acquisition + reverse geocoding pipeline
  Future<FarmerLocation?> refreshLocation({
    String? farmerMobile,
    bool forceGps = false,
  }) async {
    state = state.copyWith(status: LocationStatus.loading, errorMessage: null);

    // 1. Check if location services (GPS hardware) are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(
        status: LocationStatus.serviceDisabled,
        errorMessage: 'Location services (GPS) are turned off on your device.',
      );
      return state.location;
    }

    // 2. Check and request location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        state = state.copyWith(
          status: LocationStatus.permissionDenied,
          errorMessage: 'Location permission was denied. Tap to grant access.',
        );
        return state.location;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        status: LocationStatus.deniedForever,
        errorMessage: 'Location permission is permanently denied. Please enable in Settings.',
      );
      return state.location;
    }

    // 3. Acquire raw coordinates
    final pos = await _service.acquireRawPosition();
    if (pos == null) {
      // If we have cached location, maintain it with an error advisory
      if (state.location != null) {
        state = state.copyWith(
          status: LocationStatus.ready,
          errorMessage: 'Could not acquire fresh GPS fix. Using last verified location.',
        );
        return state.location;
      }

      state = state.copyWith(
        status: LocationStatus.error,
        errorMessage: 'Unable to acquire GPS signal. Please move outdoors or check network.',
      );
      return null;
    }

    // 4. Reverse Geocode through 3-tier pipeline
    final farmerLoc = await _service.reverseGeocode(pos.latitude, pos.longitude);

    // 5. Persist to cache and sync to Firestore
    await _service.saveCachedLocation(farmerLoc);
    unawaited(_service.syncLocationToFirestore(farmerLoc, farmerMobile: farmerMobile));

    AppActivityLogger.instance.log(
      screen: 'LocationService',
      action: 'acquireLocation',
      backendTarget: farmerLoc.reverseGeocodeSource,
      status: 'PASS',
      details: {
        'display': farmerLoc.displayLocation,
        'lat': pos.latitude,
        'lng': pos.longitude,
      },
    );

    state = state.copyWith(
      status: LocationStatus.ready,
      location: farmerLoc,
      errorMessage: null,
    );

    return farmerLoc;
  }

  Future<void> openLocationSettings() async {
    await _service.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await _service.openAppSettings();
  }
}

/// Global provider for LocationService
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Reactive single source of truth for farmer's location
final farmerLocationProvider = StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  final service = ref.watch(locationServiceProvider);
  return LocationNotifier(service);
});
