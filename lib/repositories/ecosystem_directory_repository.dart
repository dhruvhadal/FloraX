import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/florax_models.dart';
import '../services/auth/auth_role_service.dart';

/// Filter parameters for the Verified Expert Directory
@immutable
class VerifiedExpertsFilter {
  final String? category;
  final String? district;

  const VerifiedExpertsFilter({
    this.category,
    this.district,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VerifiedExpertsFilter &&
          runtimeType == other.runtimeType &&
          category == other.category &&
          district == other.district;

  @override
  int get hashCode => category.hashCode ^ district.hashCode;
}

/// Principal Repository for Human-in-the-Loop Agricultural Ecosystem
///
/// Powers the Verified Expert Directory (#10), LeafGuard Connect NGO Network (#11),
/// Second Opinion Submissions (#12), and Institutional Outbreak Reports (#14).
class EcosystemDirectoryRepository {
  final FirebaseFirestore _firestore;
  final AuthRoleService _authRoleService;

  EcosystemDirectoryRepository({
    FirebaseFirestore? firestore,
    required AuthRoleService authRoleService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authRoleService = authRoleService;

  // ===========================================================================
  // 1. VERIFIED BOTANICAL & AGRONOMIC EXPERTS (Feature #10)
  // ===========================================================================

  /// Streams verified experts across 5 disciplines (pathologist, botanist, agronomist, entomologist, horticulturist).
  /// Leverages local SQLite cache fallback when offline.
  Stream<List<VerifiedExpert>> watchVerifiedExperts({
    String? category,
    String? district,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection('verified_experts');

    if (category != null && category.isNotEmpty && category.toUpperCase() != 'ALL') {
      query = query.where('category', isEqualTo: category.toLowerCase().trim());
    }

    if (district != null && district.isNotEmpty && district.toUpperCase() != 'ALL') {
      query = query.where('district', isEqualTo: district.trim());
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => VerifiedExpert.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // ===========================================================================
  // 2. LEAFGUARD CONNECT NGO PARTNERS (Feature #11)
  // ===========================================================================

  /// Streams registered agricultural NGOs serving rural districts.
  Stream<List<NgoPartner>> watchNgoPartners({String? district}) {
    Query<Map<String, dynamic>> query = _firestore.collection('ngo_partners');

    if (district != null && district.isNotEmpty && district.toUpperCase() != 'ALL') {
      query = query.where('districtsServed', arrayContains: district.trim());
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => NgoPartner.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // ===========================================================================
  // 3. SECOND OPINION SUBMISSION & REVIEWS (Feature #12)
  // ===========================================================================

  /// Submits the farmer's LeafScanRecord to an accredited expert or NGO for a second opinion
  Future<void> submitSecondOpinionRequest({
    required LeafScanRecord scan,
    required String targetId,
    required String targetType, // 'expert' | 'ngo'
    required String farmerNotes,
  }) async {
    final user = _authRoleService.currentUser;
    final String farmerUid = user?.uid ?? scan.userId;
    final String reqId = 'SEC-${scan.scanId}';

    debugPrint(
      '[FloraX Ecosystem] Submitting second opinion request: $reqId to $targetType: $targetId',
    );

    final data = {
      'requestId': reqId,
      'farmerUid': farmerUid,
      'scanId': scan.scanId,
      'assignedExpertId': targetId,
      'assignedTargetType': targetType,
      'status': 'PENDING',
      'farmerQuery': farmerNotes,
      'cropType': scan.plantTagId,
      'aiPredictionLabel': scan.topPredictions.isNotEmpty
          ? scan.topPredictions.first.labelId
          : 'unknown',
      'aiConfidence': scan.topPredictions.isNotEmpty
          ? scan.topPredictions.first.confidence
          : 0.80,
      'severityGrade': scan.severityGrade.toFirestoreValue(),
      'imageUrl': scan.imageUrl,
      'thumbnailBase64': scan.thumbnailBase64,
      'lesionAreaPercent': scan.lesionAreaPercent,
      'geoHash5': scan.geoHash5,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('second_opinion_requests')
        .doc(reqId)
        .set(data, SetOptions(merge: true));
  }

  /// Streams the authenticated farmer's pending vs. resolved second opinion reviews
  Stream<List<SecondOpinionRequest>> watchFarmerSecondOpinionRequests(String farmerUid) {
    return _firestore
        .collection('second_opinion_requests')
        .where('farmerUid', isEqualTo: farmerUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SecondOpinionRequest.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Expert review action: Records professional feedback and resolves the ticket
  Future<void> resolveSecondOpinion({
    required String requestId,
    required String expertId,
    required String expertFeedback,
  }) async {
    await _firestore.collection('second_opinion_requests').doc(requestId).update({
      'status': 'COMPLETED',
      'assignedExpertId': expertId,
      'expertFeedback': expertFeedback,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  // ===========================================================================
  // 4. NGO ASSISTANCE REQUESTS (Feature #11)
  // ===========================================================================

  /// Submits a field assistance request to an accredited NGO partner
  Future<void> submitNgoAssistanceRequest({
    required String ngoId,
    required String farmerDistrict,
    required String cropIssue,
    required String preferredContact,
    String taluka = '',
    String cropName = 'Crop',
    String farmerName = 'Farmer',
  }) async {
    final user = _authRoleService.currentUser;
    final String farmerUid = user?.uid ?? 'farmer_anonymous';
    final String reqId = 'NGO-REQ-${DateTime.now().millisecondsSinceEpoch}';

    final data = {
      'requestId': reqId,
      'farmerUid': farmerUid,
      'farmerName': farmerName,
      'farmerPhone': preferredContact,
      'ngoId': ngoId,
      'district': farmerDistrict,
      'taluka': taluka,
      'cropName': cropName,
      'issueDescription': cropIssue,
      'status': 'PENDING',
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('ngo_assistance_requests')
        .doc(reqId)
        .set(data, SetOptions(merge: true));
  }

  // ===========================================================================
  // 5. INSTITUTION-ONLY COMMUNITY OUTBREAK REPORTING (Feature #14)
  // ===========================================================================

  /// Public read stream of verified outbreak reports confirmed by official KVK/NGO authorities
  Stream<List<VerifiedOutbreakReport>> watchVerifiedOutbreakReports({String? geoHash5}) {
    Query<Map<String, dynamic>> query = _firestore.collection('verified_outbreak_reports');

    if (geoHash5 != null && geoHash5.isNotEmpty && geoHash5.toUpperCase() != 'ALL') {
      query = query.where('geoHash5', isEqualTo: geoHash5.trim());
    }

    return query.orderBy('verifiedAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => VerifiedOutbreakReport.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Strictly restricted to authenticated institutional authorities (KVK / NGO Scientists)
  Future<void> submitInstitutionalOutbreakReport(VerifiedOutbreakReport report) async {
    final role = await _authRoleService.getCurrentUserRole();
    if (role != UserRole.kvkScientist && role != UserRole.admin) {
      throw StateError(
        'Unauthorized: Only accredited institutional authorities (KVK / NGO Specialists) may submit verified outbreak reports.',
      );
    }

    debugPrint(
      '[FloraX Ecosystem] Publishing institution-verified outbreak report: ${report.reportId}',
    );

    final docRef = _firestore.collection('verified_outbreak_reports').doc(report.reportId);
    await docRef.set(report.toFirestore(), SetOptions(merge: true));

    // Update or increment regional outbreak cluster counter
    final String clusterDocId = '${report.geoHash5}_${report.diseaseId}';
    final clusterDocRef = _firestore.collection('outbreak_clusters').doc(clusterDocId);
    await clusterDocRef.set({
      'clusterId': clusterDocId,
      'geoHash5': report.geoHash5,
      'primaryDisease': report.diseaseId,
      'diseaseCategory': 'FUNGAL',
      'confirmedCases': FieldValue.increment(1),
      'activeFarmerAlerts': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
      'taluka': report.taluka,
      'district': report.district,
    }, SetOptions(merge: true));
  }

  // ===========================================================================
  // 6. CSR & INSTITUTIONAL FUNDING PARTNERS (Feature #16)
  // ===========================================================================

  /// Streams CSR funding partners and institutional grant programs
  Stream<List<CsrFundingPartner>> watchCsrFundingPartners({String? fundingType}) {
    Query<Map<String, dynamic>> query = _firestore.collection('csr_funding_partners');

    if (fundingType != null && fundingType.isNotEmpty && fundingType.toUpperCase() != 'ALL') {
      query = query.where('fundingType', isEqualTo: fundingType.trim());
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => CsrFundingPartner.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Submits an institutional / CSR partnership inquiry to Firestore
  Future<void> submitPartnershipInquiry(PartnershipInquiry inquiry) async {
    final docRef = _firestore.collection('partnership_inquiries').doc(inquiry.inquiryId);
    await docRef.set(inquiry.toFirestore(), SetOptions(merge: true));
    debugPrint('[FloraX Ecosystem] Registered partnership inquiry: ${inquiry.inquiryId}');
  }

  /// Computes or retrieves live aggregate impact telemetry
  Future<ImpactTelemetry> fetchImpactTelemetry() async {
    try {
      // 1. Live Scans count aggregate query
      final scansCountSnap = await _firestore.collection('scans').count().get();
      final int totalScans = scansCountSnap.count ?? 0;

      // 2. Nutrient deficiencies diverted (scans identified as abiotic / nutrient deficiency)
      final scansSnap = await _firestore.collection('scans').limit(500).get();
      int abioticCount = 0;
      for (final doc in scansSnap.docs) {
        final data = doc.data();
        final preds = data['topPredictions'] as List?;
        if (preds != null && preds.isNotEmpty) {
          final first = preds.first;
          final label = first is Map ? (first['labelId']?.toString() ?? '') : '';
          if (label.startsWith('abiotic_')) {
            abioticCount++;
          }
        }
      }

      // 3. Completed second opinions count aggregate query
      final secondOpinionsCountSnap = await _firestore
          .collection('second_opinion_requests')
          .where('status', isEqualTo: 'COMPLETED')
          .count()
          .get();
      final int secondOpinionsCount = secondOpinionsCountSnap.count ?? 0;

      // 4. Outbreak alerts count aggregate query
      final outbreaksCountSnap = await _firestore
          .collection('verified_outbreak_reports')
          .count()
          .get();
      final int outbreakCount = outbreaksCountSnap.count ?? 0;

      return ImpactTelemetry(
        totalScansCount: totalScans,
        nutrientDeficienciesDiverted: abioticCount,
        expertSecondOpinionsCompleted: secondOpinionsCount,
        verifiedOutbreakAlertsIssued: outbreakCount,
        lastUpdated: DateTime.now().toUtc(),
      );
    } catch (e) {
      debugPrint('[FloraX Ecosystem] Error fetching live telemetry: $e');
      return ImpactTelemetry(
        totalScansCount: 0,
        nutrientDeficienciesDiverted: 0,
        expertSecondOpinionsCompleted: 0,
        verifiedOutbreakAlertsIssued: 0,
        lastUpdated: DateTime.now().toUtc(),
      );
    }
  }

  // ===========================================================================
  // 7. OFFLINE SQLITE CACHE PRE-WARMING (Feature #15)
  // ===========================================================================

  /// Pre-warms Firestore offline SQLite persistence by loading essential agronomic datasets
  Future<void> warmOfflineCache() async {
    try {
      debugPrint('[FloraX Offline] Pre-warming Firestore SQLite cache...');
      await Future.wait([
        _firestore.collection('icar_ipm_protocols').get(const GetOptions(source: Source.serverAndCache)),
        _firestore.collection('verified_experts').get(const GetOptions(source: Source.serverAndCache)),
        _firestore.collection('ngo_partners').get(const GetOptions(source: Source.serverAndCache)),
        _firestore.collection('csr_funding_partners').get(const GetOptions(source: Source.serverAndCache)),
      ]);
      debugPrint('[FloraX Offline] Offline SQLite cache successfully pre-warmed.');
    } catch (e) {
      debugPrint('[FloraX Offline] Cache pre-warming completed with local state: $e');
    }
  }
}

// =============================================================================
// RIVERPOD DEPENDENCY INJECTION PROVIDERS
// =============================================================================

/// Global Riverpod Provider for EcosystemDirectoryRepository
final ecosystemDirectoryRepositoryProvider =
    Provider<EcosystemDirectoryRepository>((ref) {
  final authService = ref.watch(authRoleServiceProvider);
  return EcosystemDirectoryRepository(authRoleService: authService);
});

/// Live stream provider for verified botanical and agricultural experts
final verifiedExpertsStreamProvider = StreamProvider.autoDispose
    .family<List<VerifiedExpert>, VerifiedExpertsFilter>((ref, filter) {
  final repo = ref.watch(ecosystemDirectoryRepositoryProvider);
  return repo.watchVerifiedExperts(
    category: filter.category,
    district: filter.district,
  );
});

/// Live stream provider for registered NGO partners
final ngoPartnersStreamProvider = StreamProvider.autoDispose
    .family<List<NgoPartner>, String?>((ref, district) {
  final repo = ref.watch(ecosystemDirectoryRepositoryProvider);
  return repo.watchNgoPartners(district: district);
});

/// Live stream provider for a farmer's submitted second opinion reviews
final farmerSecondOpinionRequestsStreamProvider = StreamProvider.autoDispose
    .family<List<SecondOpinionRequest>, String>((ref, farmerUid) {
  final repo = ref.watch(ecosystemDirectoryRepositoryProvider);
  return repo.watchFarmerSecondOpinionRequests(farmerUid);
});

/// Live stream provider for verified regional outbreak reports
final verifiedOutbreakReportsStreamProvider = StreamProvider.autoDispose
    .family<List<VerifiedOutbreakReport>, String?>((ref, geoHash5) {
  final repo = ref.watch(ecosystemDirectoryRepositoryProvider);
  return repo.watchVerifiedOutbreakReports(geoHash5: geoHash5);
});

/// Live stream provider for CSR funding partners
final csrFundingPartnersStreamProvider = StreamProvider.autoDispose
    .family<List<CsrFundingPartner>, String?>((ref, fundingType) {
  final repo = ref.watch(ecosystemDirectoryRepositoryProvider);
  return repo.watchCsrFundingPartners(fundingType: fundingType);
});

/// Future provider for Impact Telemetry
final impactTelemetryFutureProvider =
    FutureProvider.autoDispose<ImpactTelemetry>((ref) {
  final repo = ref.watch(ecosystemDirectoryRepositoryProvider);
  return repo.fetchImpactTelemetry();
});
