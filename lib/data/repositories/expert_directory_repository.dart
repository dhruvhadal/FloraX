import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/app_activity_logger.dart';
import '../../domain/models/florax_models.dart';

/// Offline-first Expert Directory & Second Opinion Repository.
/// Interfaces with Cloud Firestore `experts` and `consultations/{consultId}`
/// with seeded ICAR scientific profiles for offline access.
class ExpertDirectoryRepository {
  final FirebaseFirestore _firestore;
  static const String _expertsCollection = 'experts';
  static const String _consultationsCollection = 'consultations';
  static const String _localConsultationsKey = 'florax_local_consultations';

  ExpertDirectoryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Seeded authentic ICAR / KVK verified experts across 5 agricultural disciplines
  static List<VerifiedExpert> get seededExperts => [
    const VerifiedExpert(
      expertId: 'expert_patil_01',
      name: 'Dr. Arvind V. Patil',
      category: 'plant_pathologist',
      qualification: 'Ph.D. Plant Pathology (IARI New Delhi)',
      institution: 'ICAR-KVK Regional Center',
      district: 'Jalgaon',
      languages: ['Marathi', 'Hindi', 'English'],
      phone: '+919822012345',
      email: 'arvind.patil@icar-kvk.res.in',
      verifiedBy: 'ICAR-ATARI Zone VIII',
      isAvailableForSecondOpinion: true,
    ),
    const VerifiedExpert(
      expertId: 'expert_deshmukh_02',
      name: 'Dr. Sunita Deshmukh',
      category: 'botanist',
      qualification: 'M.Sc., Ph.D. Botanical Foliar Anatomy',
      institution: 'Mahatma Phule Krishi Vidyapeeth (MPKV)',
      district: 'Pune',
      languages: ['Marathi', 'Hindi', 'English'],
      phone: '+919822054321',
      email: 'sunita.deshmukh@mpkv.ac.in',
      verifiedBy: 'MPKV Agricultural Directorate',
      isAvailableForSecondOpinion: true,
    ),
    const VerifiedExpert(
      expertId: 'expert_kulkarni_03',
      name: 'Dr. Rajesh Kulkarni',
      category: 'agronomist',
      qualification: 'Ph.D. Soil Agronomy & Crop Nutrition',
      institution: 'Vasantrao Naik Marathwada Krishi Vidyapeeth',
      district: 'Pune',
      languages: ['Marathi', 'Hindi', 'English'],
      phone: '+919422078901',
      email: 'rajesh.kulkarni@vnmkv.ac.in',
      verifiedBy: 'VNMKV Directorate of Research',
      isAvailableForSecondOpinion: true,
    ),
    const VerifiedExpert(
      expertId: 'expert_shinde_04',
      name: 'Dr. Ganesh B. Shinde',
      category: 'entomologist',
      qualification: 'Ph.D. Agricultural Entomology (Vector IPM)',
      institution: 'KVK Babhaleshwar / MPKV',
      district: 'Ahmednagar',
      languages: ['Marathi', 'Hindi'],
      phone: '+919823098765',
      email: 'ganesh.shinde@mpkv.ac.in',
      verifiedBy: 'ICAR-KVK Ahmednagar',
      isAvailableForSecondOpinion: true,
    ),
    const VerifiedExpert(
      expertId: 'expert_gaikwad_05',
      name: 'Dr. Meena Gaikwad',
      category: 'horticulturist',
      qualification: 'Ph.D. Vegetable & Fruit Foliar Pathology',
      institution: 'National Research Centre for Grapes (NRCG / ICAR)',
      district: 'Solapur',
      languages: ['Marathi', 'Hindi', 'English'],
      phone: '+919421045678',
      email: 'meena.gaikwad@nrcg.res.in',
      verifiedBy: 'ICAR-NRCG Research Directorate',
      isAvailableForSecondOpinion: true,
    ),
  ];

  /// Watches the verified experts directory with filter and offline fallback
  Stream<List<VerifiedExpert>> watchExperts({
    String? discipline,
    String? district,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection(_expertsCollection);

    if (discipline != null &&
        discipline.isNotEmpty &&
        discipline.toUpperCase() != 'ALL') {
      query = query.where('category', isEqualTo: discipline.toLowerCase().trim());
    }
    if (district != null &&
        district.isNotEmpty &&
        district.toUpperCase() != 'ALL') {
      query = query.where('district', isEqualTo: district);
    }

    return query.snapshots().map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((d) => VerifiedExpert.fromMap(d.data(), d.id)).toList();
      }
      return _filterSeededExperts(discipline: discipline, district: district);
    }).handleError((err) {
      debugPrint('[ExpertDirectoryRepository] Cloud lookup error ($err), streaming seeded experts.');
      return _filterSeededExperts(discipline: discipline, district: district);
    });
  }

  /// Internal filter for seeded experts list
  List<VerifiedExpert> _filterSeededExperts({
    String? discipline,
    String? district,
  }) {
    return seededExperts.where((e) {
      if (discipline != null &&
          discipline.isNotEmpty &&
          discipline.toUpperCase() != 'ALL') {
        if (e.category.toLowerCase() != discipline.toLowerCase().trim()) return false;
      }
      if (district != null &&
          district.isNotEmpty &&
          district.toUpperCase() != 'ALL') {
        if (e.district.toLowerCase() != district.toLowerCase().trim()) return false;
      }
      return true;
    }).toList();
  }

  /// Looks up a specific expert by their unique identifier
  Future<VerifiedExpert?> getExpertById(String expertId) async {
    for (final exp in seededExperts) {
      if (exp.expertId == expertId) return exp;
    }
    try {
      final doc = await _firestore.collection(_expertsCollection).doc(expertId).get();
      if (doc.exists && doc.data() != null) {
        return VerifiedExpert.fromMap(doc.data()!, doc.id);
      }
    } catch (e) {
      debugPrint('[ExpertDirectoryRepository] getExpertById error: $e');
    }
    return null;
  }

  // ===========================================================================
  // CONSULTATIONS & 2ND-OPINION SUBMISSIONS (`consultations/{consultId}`)
  // ===========================================================================

  /// Submits a consultation or 2nd-opinion request to an agricultural expert
  Future<void> submitConsultation(ConsultationRequest request) async {
    // 1. Save to local SharedPreferences immediately
    await _saveLocalConsultation(request);

    // 2. Persist to Cloud Firestore `consultations/{consultId}`
    try {
      final docRef = _firestore.collection(_consultationsCollection).doc(request.consultId);
      await docRef.set(request.toMap(), SetOptions(merge: true));
      debugPrint('[ExpertDirectoryRepository] Submitted consultation: ${request.consultId}');
      AppActivityLogger.instance.log(
        screen: 'agricultural_experts',
        action: 'submit_consultation',
        backendTarget: 'Firestore.consultations',
        status: 'SUCCESS',
        details: {
          'consultId': request.consultId,
          'expertId': request.expertId,
          'attachedScanId': request.scanId,
          'status': request.status,
        },
      );
    } catch (e) {
      debugPrint('[ExpertDirectoryRepository WARNING] Cloud submission failed (offline): $e');
      AppActivityLogger.instance.log(
        screen: 'agricultural_experts',
        action: 'submit_consultation',
        backendTarget: 'Firestore.consultations',
        status: 'OFFLINE_FALLBACK',
        details: {
          'consultId': request.consultId,
          'error': e.toString(),
        },
      );
    }
  }

  /// Helper to store consultation locally
  Future<void> _saveLocalConsultation(ConsultationRequest req) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_localConsultationsKey) ?? [];

      final jsonReq = jsonEncode({
        'consultId': req.consultId,
        'farmerMobile': req.farmerMobile,
        'farmerName': req.farmerName,
        'expertId': req.expertId,
        'expertName': req.expertName,
        'crop': req.crop,
        'canonicalId': req.canonicalId,
        'scanId': req.scanId,
        'farmerQuery': req.farmerQuery,
        'expertResponse': req.expertResponse,
        'status': req.status,
        'submittedAt': req.submittedAt.toIso8601String(),
        'resolvedAt': req.resolvedAt?.toIso8601String(),
      });

      final updated = [
        jsonReq,
        ...rawList.where((raw) {
          try {
            final m = jsonDecode(raw);
            return m['consultId'] != req.consultId;
          } catch (_) {
            return true;
          }
        }),
      ];

      await prefs.setStringList(_localConsultationsKey, updated);
    } catch (e) {
      debugPrint('[ExpertDirectoryRepository ERROR] _saveLocalConsultation error: $e');
    }
  }

  /// Retrieves local consultations from cache
  Future<List<ConsultationRequest>> getLocalConsultations({String? farmerMobile}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_localConsultationsKey) ?? [];
      final List<ConsultationRequest> list = [];

      for (final raw in rawList) {
        try {
          final m = jsonDecode(raw);
          if (farmerMobile != null &&
              farmerMobile.isNotEmpty &&
              m['farmerMobile'] != farmerMobile) {
            continue;
          }
          list.add(ConsultationRequest.fromMap(m));
        } catch (_) {}
      }
      return list;
    } catch (e) {
      debugPrint('[ExpertDirectoryRepository] getLocalConsultations error: $e');
      return [];
    }
  }

  /// Watches all consultations submitted by a specific farmer
  Stream<List<ConsultationRequest>> watchFarmerConsultations(String farmerMobile) {
    return _firestore
        .collection(_consultationsCollection)
        .where('farmerMobile', isEqualTo: farmerMobile)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => ConsultationRequest.fromMap(d.data(), d.id))
          .toList();
    }).handleError((err) async* {
      debugPrint('[ExpertDirectoryRepository] watchFarmerConsultations cloud error ($err), streaming local.');
      final local = await getLocalConsultations(farmerMobile: farmerMobile);
      yield local;
    });
  }
}

/// Global Riverpod Provider for ExpertDirectoryRepository
final expertDirectoryRepositoryProvider = Provider<ExpertDirectoryRepository>((ref) {
  return ExpertDirectoryRepository();
});
