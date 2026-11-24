import 'package:flutter/material.dart';

import '../../presentation/screens/assistance/assistance_hub_screen.dart';
import '../../presentation/screens/assistance/emergency_aid_application_screen.dart';
import '../../presentation/screens/assistance/equipment_support_application_screen.dart';
import '../../presentation/screens/assistance/farm_inputs_application_screen.dart';
import '../../presentation/screens/assistance/financial_aid_application_screen.dart';
import '../../presentation/screens/assistance/ngo_support_application_screen.dart';
import '../../presentation/screens/assistance/technical_assistance_application_screen.dart';
import '../../presentation/screens/auth/app_permissions_flow_screen.dart';
import '../../presentation/screens/auth/language_selection_screen.dart';
import '../../presentation/screens/auth/welcome_registration_screen.dart';
import '../../presentation/screens/companion/help_support_screen.dart';
import '../../presentation/screens/companion/my_crops_screen.dart';
import '../../presentation/screens/companion/offline_guides_screen.dart';
import '../../presentation/screens/companion/scan_history_screen.dart';
import '../../presentation/screens/companion/weather_forecast_screen.dart';
import '../../presentation/screens/experts/agricultural_experts_screen.dart';
import '../../presentation/screens/home/home_dashboard_screen.dart';
import '../../presentation/screens/profile/user_profile_screen.dart';
import '../../presentation/screens/radar/regional_outbreak_radar_screen.dart';
import '../../presentation/screens/scanner/camera_scan_screen.dart';
import '../../presentation/screens/scanner/diagnosis_details_screen.dart';

/// Centralized Route Name Definitions for KisanSetu
class AppRoutes {
  AppRoutes._();

  // Core Authentication & Onboarding (Screens 0, 1 & 2)
  static const String languageSelection = '/language-selection';
  static const String welcome = '/welcome';
  static const String permissions = '/permissions';

  // Primary Shell & Dashboard (Screen 3)
  static const String home = '/home';

  // Pathology Scanner & Diagnosis (Screens 5 & 6)
  static const String scanner = '/scanner';
  static const String diagnosis = '/diagnosis';

  // Outbreak Radar & Crop Progression (Screens 7 & Progression)
  static const String radar = '/radar';
  static const String progression = '/progression';

  // Farmer Profile & Device Settings (Screen 9)
  static const String profile = '/profile';

  // Agricultural Experts & 2nd-Opinion Hub (Screen 8)
  static const String experts = '/experts';

  // Companion Utility Screens (Baby Step 4)
  static const String scanHistory = '/scan-history';
  static const String weather = '/weather';
  static const String offlineGuides = '/offline-guides';
  static const String helpSupport = '/help-support';

  // Assistance Hub & Form Pathways (Baby Step 5: Screens 10–16)
  static const String assistanceHub = '/assistance-hub';
  static const String assistanceFinancial = '/assistance/financial';
  static const String assistanceInputs = '/assistance/inputs';
  static const String assistanceEquipment = '/assistance/equipment';
  static const String assistanceEmergency = '/assistance/emergency';
  static const String assistanceTechnical = '/assistance/technical';
  static const String assistanceNgo = '/assistance/ngo';
}

/// Central App Router with declarative route generation
class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.languageSelection:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const LanguageSelectionScreen(),
        );

      case '/':
      case AppRoutes.welcome:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const WelcomeRegistrationScreen(),
        );

      case AppRoutes.permissions:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AppPermissionsFlowScreen(),
        );

      case AppRoutes.home:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const HomeDashboardScreen(),
        );

      case AppRoutes.scanner:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const CameraScanScreen(),
        );

      case AppRoutes.diagnosis:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const DiagnosisDetailsScreen(),
        );

      case AppRoutes.radar:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const RegionalOutbreakRadarScreen(),
        );

      case AppRoutes.progression:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const MyCropsScreen(),
        );

      case AppRoutes.scanHistory:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ScanHistoryScreen(),
        );

      case AppRoutes.weather:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const WeatherForecastScreen(),
        );

      case AppRoutes.offlineGuides:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const OfflineGuidesScreen(),
        );

      case AppRoutes.helpSupport:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const HelpSupportScreen(),
        );

      case AppRoutes.profile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const UserProfileScreen(),
        );

      case AppRoutes.experts:
        final args = settings.arguments as Map<String, dynamic>?;
        final scanId = (args?['attachedScanId'] ?? args?['flxScanId']) as String?;
        final canonicalId = args?['canonicalId'] as String?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => AgriculturalExpertsScreen(
            attachedScanId: scanId,
            canonicalId: canonicalId,
          ),
        );

      // Baby Step 5: Screens 10–16
      case AppRoutes.assistanceHub:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AssistanceHubScreen(),
        );

      case AppRoutes.assistanceFinancial:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const FinancialAidApplicationScreen(),
        );

      case AppRoutes.assistanceInputs:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const FarmInputsApplicationScreen(),
        );

      case AppRoutes.assistanceEquipment:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const EquipmentSupportApplicationScreen(),
        );

      case AppRoutes.assistanceEmergency:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const EmergencyAidApplicationScreen(),
        );

      case AppRoutes.assistanceTechnical:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const TechnicalAssistanceApplicationScreen(),
        );

      case AppRoutes.assistanceNgo:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const NgoSupportApplicationScreen(),
        );

      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const HomeDashboardScreen(),
        );
    }
  }
}
