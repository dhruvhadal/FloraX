import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/app_activity_logger.dart';
import '../../domain/models/florax_models.dart';

/// Unified Polymorphic Assistance Repository.
/// Backed by Cloud Firestore `assistance_applications/{appId}`, `available_programs`,
/// and `ngo_directory` with persistent offline SharedPreferences cache.
class AssistanceRepository {
  final FirebaseFirestore _firestore;
  static const String _applicationsCollection = 'assistance_applications';
  static const String _programsCollection = 'available_programs';
  static const String _ngoCollection = 'ngo_directory';
  static const String _localApplicationsKey = 'florax_local_assistance_apps';

  AssistanceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Seeded Government & CSR Aid Programs covering all 6 assistance categories
  static List<AidProgram> get seededPrograms => [
    // 1. FINANCIAL AID
    const AidProgram(
      programId: 'prog_pm_kisan_01',
      category: AssistanceCategory.financial,
      title: {
        'en': 'PM-KISAN Income Support & Foliar Recovery Grant',
        'hi': 'पीएम-किसान सम्मान निधि एवं फसल सुधार सहायता',
        'mr': 'पीएम-किसान व नमो शेतकरी महासन्मान निधी',
      },
      description: {
        'en': 'Direct benefit transfer providing financial relief for disease-damaged crop restoration.',
        'hi': 'रोगग्रस्त फसलों के सुधार हेतु किसानों को प्रत्यक्ष वित्तीय सहायता।',
        'mr': 'पीक नुकसान आणि रोग नियंत्रणासाठी थेट आर्थिक अनुदान.',
      },
      eligibleState: 'ALL',
      sponsoringAgency: 'Ministry of Agriculture & Farmers Welfare, GoI',
      maxBenefitAmount: 6000.0,
      requiredDocuments: ['Aadhaar Card', '7/12 Land Record (Satbara)', 'Bank Passbook'],
      isActive: true,
      isInformationalOnly: true,
    ),
    const AidProgram(
      programId: 'prog_pmfby_relief_02',
      category: AssistanceCategory.financial,
      title: {
        'en': 'PMFBY Post-Harvest & Localized Crop Loss Relief',
        'hi': 'प्रधानमंत्री फसल बीमा योजना (स्थानीय आपदा राहत)',
        'mr': 'पंतप्रधान पीक विमा योजना (स्थानिक रोग व कीड भरपाई)',
      },
      description: {
        'en': 'Comprehensive risk cover for severe foliar disease epidemics leading to yield loss.',
        'hi': 'गंभीर रोग प्रकोप के कारण फसल उत्पादन में भारी गिरावट की स्थिति में बीमा भरपाई।',
        'mr': 'रोगाच्या उद्रेकामुळे होणाऱ्या उत्पादनातील नुकसानीची विमा भरपाई.',
      },
      eligibleState: 'ALL',
      sponsoringAgency: 'PMFBY / Department of Agriculture, Maharashtra',
      maxBenefitAmount: 45000.0,
      requiredDocuments: ['Crop Insurance Policy No.', 'KisanSetu Diagnostic Scan ID', '7/12 Utara'],
      isActive: true,
      isInformationalOnly: true,
    ),

    // 2. FARM INPUTS AID
    const AidProgram(
      programId: 'prog_nfsm_inputs_03',
      category: AssistanceCategory.inputs,
      title: {
        'en': 'ICAR Certified Bio-Fungicide & Bio-Pesticide Seed Kit',
        'hi': 'आईसीएआर प्रमाणित जैव-फफूंदनाशक एवं बीज उपचार किट',
        'mr': 'आयसीआर प्रमाणित जैविक बुरशीनाशक व बीज प्रक्रिया किट',
      },
      description: {
        'en': 'Subsidized allocation of Trichoderma viride, Pseudomonas, and cold-pressed Neem Oil.',
        'hi': 'ट्राइकोडर्मा, स्यूडोमोनास तथा नीम तेल की रियायती जैविक इनपुट किट।',
        'mr': 'ट्रायकोडर्मा, स्यूडोमोनास व नीम तेल यांचा मोफत/सवलतीच्या दरातील संच.',
      },
      eligibleState: 'Maharashtra',
      sponsoringAgency: 'National Food Security Mission (NFSM) / ICAR',
      maxBenefitAmount: 2500.0,
      requiredDocuments: ['Aadhaar Card', 'Farmer Registration ID'],
      isActive: true,
      isInformationalOnly: true,
    ),

    // 3. EQUIPMENT SUPPORT
    const AidProgram(
      programId: 'prog_smam_sprayers_04',
      category: AssistanceCategory.equipment,
      title: {
        'en': 'SMAM 50% Subsidy on Battery Knapsack Sprayers',
        'hi': 'बैटरी चालित नैपसैक स्प्रेयर पर 50% सरकारी अनुदान',
        'mr': 'बॅटरी ऑपरेटेड नॅपसॅक पंपावर ५०% शासकीय अनुदान',
      },
      description: {
        'en': 'Financial subsidy for purchasing dual-nozzle pressure sprayers ensuring even canopy biocontrol.',
        'hi': 'दवा छिड़काव हेतु आधुनिक बैटरी पंप की खरीद पर 50% की सीधी छूट।',
        'mr': 'फवारणीसाठी आधुनिक बॅटरी पंपाच्या खरेदीवर थेट ५०% अनुदान.',
      },
      eligibleState: 'ALL',
      sponsoringAgency: 'Sub-Mission on Agricultural Mechanization (SMAM)',
      maxBenefitAmount: 3500.0,
      requiredDocuments: ['7/12 Land Record', 'Aadhaar Card', 'Quotation / Bill'],
      isActive: true,
      isInformationalOnly: true,
    ),

    // 4. EMERGENCY AID
    const AidProgram(
      programId: 'prog_disaster_emergency_05',
      category: AssistanceCategory.emergency,
      title: {
        'en': 'SDRF Emergency Relief for Hailstorm & Unseasonal Rain Damage',
        'hi': 'अतिवृष्टि एवं ओलावृष्टि आपदा राहत अनुदान',
        'mr': 'अतिवृष्टी व गारपीट आपत्कालीन रोग प्रतिबंधक मदत निधी',
      },
      description: {
        'en': 'Emergency financial assistance for fields hit by hailstorms triggering fungal wound infections.',
        'hi': 'ओलावृष्टि और बेमौसम बारिश से हुए नुकसान हेतु त्वरित आपातकालीन सहायता।',
        'mr': 'गारपीट आणि अवकाळी पावसाने झालेल्या नुकसानीसाठी तातडीची आर्थिक मदत.',
      },
      eligibleState: 'Maharashtra',
      sponsoringAgency: 'State Disaster Response Fund (SDRF) Maharashtra',
      maxBenefitAmount: 13500.0,
      requiredDocuments: ['Panchanama Report', 'Geo-tagged Scan Photos', 'Bank Account Details'],
      isActive: true,
      isInformationalOnly: true,
    ),

    // 5. TECHNICAL ASSISTANCE
    const AidProgram(
      programId: 'prog_kvk_soil_tech_06',
      category: AssistanceCategory.technical,
      title: {
        'en': 'KVK Soil Health Card & Free Micro-Nutrient Foliar Profiling',
        'hi': 'केवीके मृदा स्वास्थ्य कार्ड एवं सूक्ष्म पोषक तत्व जांच',
        'mr': 'केव्हीके मृदा आरोग्य पत्रिका व मोफत सूक्ष्म अन्नद्रव्य तपासणी',
      },
      description: {
        'en': 'Comprehensive laboratory analysis of foliar chlorosis and soil micronutrient deficiencies.',
        'hi': 'मिट्टी एवं पत्तियों की निःशुल्क प्रयोगशाला जांच और वैज्ञानिक परामर्श।',
        'mr': 'माती आणि पानांचे मोफत लॅब परीक्षण व शास्त्रज्ञांचा प्रत्यक्ष सल्ला.',
      },
      eligibleState: 'ALL',
      sponsoringAgency: 'ICAR-Agricultural Technology Application Research Institute (ATARI)',
      maxBenefitAmount: 1200.0,
      requiredDocuments: ['Soil Sample Slip', 'Farmer Mobile Number'],
      isActive: true,
      isInformationalOnly: true,
    ),

    // 6. NGO / CSR COMMUNITY AID
    const AidProgram(
      programId: 'prog_csr_leafguard_07',
      category: AssistanceCategory.ngo,
      title: {
        'en': 'LeafGuard Connect Organic Transition Seed Fund',
        'hi': 'लीफगार्ड कनेक्ट जैविक खेती संक्रमण सहायता अनुदान',
        'mr': 'लीफगार्ड कनेक्ट सेंद्रिय शेती प्रोत्साहन निधी (CSR)',
      },
      description: {
        'en': 'Philanthropic CSR grant funding non-chemical pest management and bio-fertilizer drums.',
        'hi': 'रासायनिक दवाओं के स्थान पर जैविक खेती अपनाने वाले छोटे किसानों हेतु अनुदान।',
        'mr': 'सेंद्रिय शेतीकडे वळणाऱ्या अल्पभूधारक शेतकऱ्यांसाठी सीएसआर अनुदान.',
      },
      eligibleState: 'Maharashtra',
      sponsoringAgency: 'Tata Trusts & BAIF Development Research Foundation',
      maxBenefitAmount: 8000.0,
      requiredDocuments: ['Farmer Certificate', 'Aadhaar Card', 'Field Photos'],
      isActive: true,
      isInformationalOnly: false,
    ),
  ];

  /// Seeded NGO & CSR Directory searchable by name, district, or pin code
  static List<NgoPartner> get seededNgos => [
    const NgoPartner(
      ngoId: 'ngo_baif_01',
      name: 'BAIF Development Research Foundation',
      registrationNumber: 'MH/2017/0115432',
      focusAreas: ['organic_transition', 'bio_inputs', 'equipment_grant'],
      districtsServed: ['Pune', 'Ahmednagar', 'Solapur', 'Nandurbar', 'Satara'],
      fieldRepName: 'Sanjay Deshmukh',
      fieldRepContact: '+912025231661',
      activeAwarenessPrograms: ['Tribal Natural Farming Mission', 'Cow-based Bio-formulations'],
      farmerSupportSchemes: ['PM-KISAN Convergence', 'Free Trichoderma Distribution'],
    ),
    const NgoPartner(
      ngoId: 'ngo_dilasa_02',
      name: 'Dilasa Janvikas Pratishthan',
      registrationNumber: 'MH/2018/0198741',
      focusAreas: ['emergency_relief', 'cotton_ipm', 'seeds'],
      districtsServed: ['Jalgaon', 'Aurangabad', 'Jalna', 'Amravati', 'Yavatmal'],
      fieldRepName: 'Pravin Kadam',
      fieldRepContact: '+912402345678',
      activeAwarenessPrograms: ['Cotton Leaf Curl Eradication Drive', 'Yellow Sticky Trap Workshop'],
      farmerSupportSchemes: ['CSR Cotton Subsidy', 'Bio-fertilizer Kit'],
    ),
    const NgoPartner(
      ngoId: 'ngo_swades_03',
      name: 'Swades Foundation',
      registrationNumber: 'MH/2016/0091234',
      focusAreas: ['paddy_blast_control', 'equipment_grant', 'financial_aid'],
      districtsServed: ['Raigad', 'Ratnagiri'],
      fieldRepName: 'Anil Parab',
      fieldRepContact: '+912261076200',
      activeAwarenessPrograms: ['Coastal Paddy Disease Surveillance', 'Drip Irrigation Setup'],
      farmerSupportSchemes: ['50% Sprayer Subsidy Top-up', 'Emergency Crop Loss Relief'],
    ),
    const NgoPartner(
      ngoId: 'ngo_yuvamitra_04',
      name: 'Yuva Mitra Rural Development Organization',
      registrationNumber: 'MH/2019/0223456',
      focusAreas: ['technical_assistance', 'bio_inputs', 'organic_transition'],
      districtsServed: ['Dhule', 'Jalgaon', 'Ahmednagar'],
      fieldRepName: 'Mahesh Gaikwad',
      fieldRepContact: '+912532578901',
      activeAwarenessPrograms: ['Tomato Early Blight Bio-wash Program', 'Soil Health Testing Camp'],
      farmerSupportSchemes: ['Organic Transition Grant', 'Free Pseudomonas Inoculum'],
    ),
  ];

  // ===========================================================================
  // 1. APPLICATIONS MANAGEMENT (`assistance_applications/{appId}`)
  // ===========================================================================

  /// Submits an assistance application.
  /// Strictly restricted to NGO Support applications. Government schemes and subsidies are read-only informational records.
  Future<void> submitApplication(AssistanceApplication app) async {
    if (app.category != AssistanceCategory.ngo) {
      throw UnsupportedError(
        'Government schemes and subsidies (${app.category.name}) are strictly informational records. Only NGO Support applications can be submitted.',
      );
    }

    // 1. Cache locally first
    await _saveLocalApplication(app);

    // 2. Persist to Firestore
    try {
      final docRef = _firestore.collection(_applicationsCollection).doc(app.appId);
      await docRef.set(app.toMap(), SetOptions(merge: true));
      debugPrint('[AssistanceRepository] Submitted application: ${app.appId} [${app.category.name}]');
      AppActivityLogger.instance.log(
        screen: 'assistance_application',
        action: 'submit_aid_application',
        backendTarget: 'Firestore.assistance_applications',
        status: 'SUCCESS',
        details: {
          'appId': app.appId,
          'category': app.category.name,
          'programTitle': app.programTitle,
          'farmerMobile': app.farmerMobile,
          'requestedAmount': app.requestedAmount,
          'status': app.status,
        },
      );
    } catch (e) {
      debugPrint('[AssistanceRepository WARNING] Cloud application sync failed (offline): $e');
      AppActivityLogger.instance.log(
        screen: 'assistance_application',
        action: 'submit_aid_application',
        backendTarget: 'Firestore.assistance_applications',
        status: 'OFFLINE_FALLBACK',
        details: {
          'appId': app.appId,
          'category': app.category.name,
          'error': e.toString(),
        },
      );
    }
  }

  /// Internal helper to save application locally
  Future<void> _saveLocalApplication(AssistanceApplication app) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_localApplicationsKey) ?? [];

      final jsonApp = jsonEncode({
        'appId': app.appId,
        'farmerMobile': app.farmerMobile,
        'farmerName': app.farmerName,
        'district': app.district,
        'state': app.state,
        'pinCode': app.pinCode,
        'category': app.category.value,
        'programId': app.programId,
        'programTitle': app.programTitle,
        'details': app.details,
        'requestedAmount': app.requestedAmount,
        'status': app.status,
        'appliedAt': app.appliedAt.toIso8601String(),
        'metadata': app.metadata,
      });

      final updated = [
        jsonApp,
        ...rawList.where((raw) {
          try {
            final m = jsonDecode(raw);
            return m['appId'] != app.appId;
          } catch (_) {
            return true;
          }
        }),
      ];

      await prefs.setStringList(_localApplicationsKey, updated);
    } catch (e) {
      debugPrint('[AssistanceRepository ERROR] _saveLocalApplication error: $e');
    }
  }

  /// Retrieves local cached applications
  Future<List<AssistanceApplication>> getLocalApplications({String? farmerMobile}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_localApplicationsKey) ?? [];
      final List<AssistanceApplication> list = [];

      for (final raw in rawList) {
        try {
          final m = jsonDecode(raw);
          if (farmerMobile != null &&
              farmerMobile.isNotEmpty &&
              m['farmerMobile'] != farmerMobile) {
            continue;
          }
          list.add(AssistanceApplication.fromMap(m));
        } catch (_) {}
      }
      return list;
    } catch (e) {
      debugPrint('[AssistanceRepository] getLocalApplications error: $e');
      return [];
    }
  }

  /// Real-time stream of all assistance applications filed by a specific farmer
  Stream<List<AssistanceApplication>> watchFarmerApplications(String farmerMobile) {
    return _firestore
        .collection(_applicationsCollection)
        .where('farmerMobile', isEqualTo: farmerMobile)
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => AssistanceApplication.fromMap(d.data(), d.id))
          .toList();
    }).handleError((err) async* {
      debugPrint('[AssistanceRepository] watchFarmerApplications cloud error ($err), streaming local.');
      final local = await getLocalApplications(farmerMobile: farmerMobile);
      yield local;
    });
  }

  // ===========================================================================
  // 2. AVAILABLE AID PROGRAMS (`available_programs`)
  // ===========================================================================

  /// Fetches available government and CSR programs filtered by category or state
  Future<List<AidProgram>> getAvailablePrograms({
    AssistanceCategory? category,
    String? state,
  }) async {
    List<AidProgram> all = [];

    try {
      Query<Map<String, dynamic>> query = _firestore.collection(_programsCollection);
      if (category != null) {
        query = query.where('category', isEqualTo: category.value);
      }
      final snap = await query.get();
      if (snap.docs.isNotEmpty) {
        all = snap.docs.map((d) => AidProgram.fromMap(d.data(), d.id)).toList();
      }
    } catch (e) {
      debugPrint('[AssistanceRepository] getAvailablePrograms cloud lookup fallback: $e');
    }

    if (all.isEmpty) {
      all = seededPrograms;
    }

    return all.where((prog) {
      if (!prog.isActive) return false;
      if (category != null && prog.category != category) return false;
      if (state != null && state.isNotEmpty && prog.eligibleState != 'ALL') {
        if (prog.eligibleState.toLowerCase() != state.toLowerCase()) return false;
      }
      return true;
    }).toList();
  }

  // ===========================================================================
  // 3. NGO & CSR DIRECTORY SEARCH (`ngo_directory`)
  // ===========================================================================

  /// Searches verified NGOs and CSR partners by text query, district, or pin code
  Future<List<NgoPartner>> searchNgoDirectory({
    String? query,
    String? district,
    String? pinCode,
  }) async {
    List<NgoPartner> all = [];

    try {
      final snap = await _firestore.collection(_ngoCollection).get();
      if (snap.docs.isNotEmpty) {
        all = snap.docs.map((d) => NgoPartner.fromMap(d.data(), d.id)).toList();
      }
    } catch (e) {
      debugPrint('[AssistanceRepository] searchNgoDirectory cloud fallback: $e');
    }

    if (all.isEmpty) {
      all = seededNgos;
    }

    final q = query?.toLowerCase().trim();
    final d = district?.toLowerCase().trim();

    return all.where((ngo) {
      if (q != null && q.isNotEmpty) {
        final inName = ngo.name.toLowerCase().contains(q);
        final inFocus = ngo.focusAreas.any((f) => f.toLowerCase().contains(q));
        if (!inName && !inFocus) return false;
      }

      if (d != null && d.isNotEmpty && d != 'all') {
        final matchesDistrict = ngo.districtsServed.any((dc) => dc.toLowerCase().contains(d));
        if (!matchesDistrict) return false;
      }

      return true;
    }).toList();
  }
}

/// Global Riverpod Provider for AssistanceRepository
final assistanceRepositoryProvider = Provider<AssistanceRepository>((ref) {
  return AssistanceRepository();
});
