import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:florax/services/location/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocationService — Haversine Distance Calculations', () {
    test('Calculates accurate distance between Mumbai and Pune (~120 km)', () {
      const double mumbaiLat = 18.9220;
      const double mumbaiLng = 72.8347;
      const double puneLat = 18.5204;
      const double puneLng = 73.8567;

      final distanceKm = LocationService.calculateDistanceKm(
        mumbaiLat,
        mumbaiLng,
        puneLat,
        puneLng,
      );

      // Known approximate geodesic distance between Mumbai and Pune is ~118-125 km
      expect(distanceKm, greaterThan(115.0));
      expect(distanceKm, lessThan(130.0));
    });

    test('Identical coordinates return 0.0 km distance', () {
      final distanceKm = LocationService.calculateDistanceKm(
        19.0000,
        74.0000,
        19.0000,
        74.0000,
      );

      expect(distanceKm, closeTo(0.0, 0.001));
    });

    test('Distance calculation is symmetric', () {
      final distAB = LocationService.calculateDistanceKm(18.5, 73.8, 19.9, 74.5);
      final distBA = LocationService.calculateDistanceKm(19.9, 74.5, 18.5, 73.8);

      expect(distAB, closeTo(distBA, 0.001));
    });
  });

  group('FarmerLocation Model & Display Formatting', () {
    test('Formats display string with village and district when both present', () {
      final loc = FarmerLocation(
        latitude: 18.1513,
        longitude: 74.5772,
        village: 'Baramati',
        district: 'Pune',
        state: 'Maharashtra',
        postalCode: '413102',
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(loc.displayLocation, equals('Baramati, Pune'));
      expect(loc.fullAddress, equals('Baramati, Pune, Maharashtra, 413102'));
    });

    test('Formats display string with district and state when village is empty', () {
      final loc = FarmerLocation(
        latitude: 18.5204,
        longitude: 73.8567,
        village: '',
        district: 'Pune',
        state: 'Maharashtra',
        postalCode: '411001',
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(loc.displayLocation, equals('Pune, Maharashtra'));
    });

    test('Formats display string with formatted coordinates when offline only', () {
      final loc = FarmerLocation(
        latitude: 19.0642,
        longitude: 73.0124,
        village: '',
        district: '',
        state: '',
        postalCode: '',
        isOfflineCoordinatesOnly: true,
        reverseGeocodeSource: 'offline_coordinates',
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(loc.displayLocation, equals('19.0642° N, 73.0124° E • Offline GPS'));
    });

    test('Serializes to and from JSON correctly', () {
      final original = FarmerLocation(
        latitude: 17.6805,
        longitude: 74.0183,
        village: 'Karad',
        district: 'Satara',
        state: 'Maharashtra',
        postalCode: '415110',
        isOfflineCoordinatesOnly: false,
        reverseGeocodeSource: 'osm_nominatim',
        updatedAt: DateTime(2026, 6, 15, 10, 30),
      );

      final jsonStr = original.toJson();
      final reconstructed = FarmerLocation.fromJson(jsonStr);

      expect(reconstructed.latitude, equals(original.latitude));
      expect(reconstructed.longitude, equals(original.longitude));
      expect(reconstructed.village, equals(original.village));
      expect(reconstructed.district, equals(original.district));
      expect(reconstructed.state, equals(original.state));
      expect(reconstructed.postalCode, equals(original.postalCode));
      expect(reconstructed.reverseGeocodeSource, equals('osm_nominatim'));
      expect(reconstructed, equals(original));
    });
  });

  group('LocationState & Status Enum', () {
    test('State getters map correctly to statuses', () {
      const initial = LocationState(status: LocationStatus.initial);
      expect(initial.isLoading, isFalse);
      expect(initial.isReady, isFalse);

      const loading = LocationState(status: LocationStatus.loading);
      expect(loading.isLoading, true);

      const disabled = LocationState(status: LocationStatus.serviceDisabled);
      expect(disabled.isServiceDisabled, true);

      const denied = LocationState(status: LocationStatus.permissionDenied);
      expect(denied.isPermissionDenied, true);

      const deniedForever = LocationState(status: LocationStatus.deniedForever);
      expect(deniedForever.isDeniedForever, true);

      final ready = LocationState(
        status: LocationStatus.ready,
        location: FarmerLocation(
          latitude: 18.5,
          longitude: 73.8,
          village: 'Pune',
          district: 'Pune',
          state: 'Maharashtra',
          postalCode: '411001',
          updatedAt: DateTime.now(),
        ),
      );
      expect(ready.isReady, true);
    });
  });

  group('LocationService — 3-Tier Reverse Geocoding', () {
    test('Tier B: Successfully falls back to OpenStreetMap Nominatim when native fails', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, equals('nominatim.openstreetmap.org'));
        expect(request.headers['User-Agent'], contains('KisanSetu'));

        final responseJson = jsonEncode({
          'address': {
            'village': 'Rahuri',
            'state_district': 'Ahmednagar',
            'state': 'Maharashtra',
            'postcode': '413722',
          }
        });
        return http.Response(responseJson, 200, headers: {'content-type': 'application/json'});
      });

      final service = LocationService(httpClient: mockClient);
      final loc = await service.reverseGeocode(19.3900, 74.6500);

      expect(loc.village, equals('Rahuri'));
      expect(loc.district, equals('Ahmednagar'));
      expect(loc.state, equals('Maharashtra'));
      expect(loc.postalCode, equals('413722'));
      expect(loc.reverseGeocodeSource, equals('osm_nominatim'));
      expect(loc.isOfflineCoordinatesOnly, false);
      expect(loc.displayLocation, equals('Rahuri, Ahmednagar'));
    });

    test('Tier C: Falls back to offline coordinates when both Tier A and Tier B fail', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('No Internet Connection in deep field');
      });

      final service = LocationService(httpClient: mockClient);
      final loc = await service.reverseGeocode(19.0642, 73.0124);

      expect(loc.latitude, equals(19.0642));
      expect(loc.longitude, equals(73.0124));
      expect(loc.village, isEmpty);
      expect(loc.district, isEmpty);
      expect(loc.isOfflineCoordinatesOnly, true);
      expect(loc.reverseGeocodeSource, equals('offline_coordinates'));
      expect(loc.displayLocation, contains('19.0642° N, 73.0124° E • Offline GPS'));
    });
  });

  group('LocationService — SharedPreferences Local Caching', () {
    test('Saves and restores cached location from local persistent storage', () async {
      SharedPreferences.setMockInitialValues({});
      final service = LocationService();

      final originalLoc = FarmerLocation(
        latitude: 16.7050,
        longitude: 74.2433,
        village: 'Panhala',
        district: 'Kolhapur',
        state: 'Maharashtra',
        postalCode: '416201',
        updatedAt: DateTime(2026, 5, 20),
      );

      await service.saveCachedLocation(originalLoc);
      final cachedLoc = await service.getCachedLocation();

      expect(cachedLoc, isNotNull);
      expect(cachedLoc!.village, equals('Panhala'));
      expect(cachedLoc.district, equals('Kolhapur'));
      expect(cachedLoc.latitude, equals(16.7050));
      expect(cachedLoc.postalCode, equals('416201'));
    });

    test('LocationNotifier loads cached location on initialization', () async {
      final cachedLoc = FarmerLocation(
        latitude: 18.5204,
        longitude: 73.8567,
        village: 'Shivajinagar',
        district: 'Pune',
        state: 'Maharashtra',
        postalCode: '411005',
        updatedAt: DateTime(2026, 4, 1),
      );

      SharedPreferences.setMockInitialValues({
        LocationService.cacheKey: cachedLoc.toJson(),
      });

      final service = LocationService();
      final notifier = LocationNotifier(service);

      // Wait a microtask turn for _initFromCache() to settle
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.status, equals(LocationStatus.ready));
      expect(notifier.state.location, isNotNull);
      expect(notifier.state.location!.district, equals('Pune'));
      expect(notifier.state.location!.village, equals('Shivajinagar'));
    });
  });
}
