// ignore_for_file: unused_import

import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../models/app_module.dart';
import 'common_service.dart';

/// Mirrors Android's WKBaseApplication module logic
/// - Holds current list of AppModule for the logged-in user
/// - Provides appModuleIsInjection() to decide whether a module should be active
class ModuleGatekeeper {
  ModuleGatekeeper._internal();
  static final ModuleGatekeeper instance = ModuleGatekeeper._internal();

  List<AppModule> _modules = [];

  void setModules(List<AppModule> modules) {
    _modules = List<AppModule>.from(modules);
  }

  Future<void> loadFromStorage() async {
    final list = await CommonService().loadSavedAppModules();
    _modules = list;
  }

  AppModule? getAppModuleWithSid(String sid) {
    for (final m in _modules) {
      if (m.sid == sid) return m;
    }
    return null;
  }

  /// Returns true when module is effectively enabled for injection (feature active)
  /// Android: return appModule == null || (appModule.status != 0 && appModule.checked)
  bool appModuleIsInjection(AppModule? appModule) {
    if (appModule == null) return true;
    return appModule.status != 0 && appModule.checked;
  }
}
