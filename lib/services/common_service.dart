import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../models/app_module.dart';
import '../utils/logger.dart';

class CommonService {
  static final CommonService _instance = CommonService._internal();
  factory CommonService() => _instance;
  CommonService._internal();

  Dio _createDio() {
    final dio = Dio();
    dio.options.baseUrl = WKApiConfig.baseUrl.isNotEmpty
        ? WKApiConfig.baseUrl
        : '${WKApiConfig.defaultBaseUrl}/v1/';
    dio.options.connectTimeout = const Duration(seconds: 8);
    dio.options.receiveTimeout = const Duration(seconds: 8);
    dio.options.headers = {
      'Content-Type': 'application/json',
      'package': AppInfo.packageName,
      'os': 'Flutter',
      'appid': 'wukongchat',
      'model': 'flutter_app',
      'version': '1.0',
    };
    return dio;
  }

  Future<String> _getAppModuleKey() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(WKConstants.uidKey);
    if (uid != null && uid.isNotEmpty) {
      return '${uid}_${WKConstants.appModuleKey}';
    }
    return WKConstants.appModuleKey;
  }

  /// GET /common/appmodule returns a list of modules
  Future<List<AppModule>> getAppModules() async {
    try {
      final dio = _createDio();
      // Attach token if available (matches Android interceptor behavior)
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(WKConstants.tokenKey);
      if (token != null && token.isNotEmpty) {
        dio.options.headers['token'] = token;
      }
      final resp = await dio.get('common/appmodule');
      if (resp.statusCode == 200) {
        final data = resp.data;
        if (data is List) {
          final serverList = data
              .map((e) => AppModule.fromJson(e as Map<String, dynamic>))
              .toList();
          return _mergeWithLocalSelection(serverList);
        }
      }
      return [];
    } catch (e, st) {
      Logger.error('getAppModules failed', error: e, stackTrace: st);
      return [];
    }
  }

  Future<void> saveAppModules(List<AppModule> modules) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(modules.map((e) => e.toJson()).toList());
      final key = await _getAppModuleKey();
      await prefs.setString(key, json);
    } catch (e) {
      Logger.error('saveAppModules failed', error: e);
    }
  }

  Future<List<AppModule>> loadSavedAppModules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getAppModuleKey();
      final text = prefs.getString(key);
      if (text == null || text.isEmpty) return [];
      final list = (jsonDecode(text) as List)
          .map((e) => AppModule.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    } catch (e) {
      return [];
    }
  }

  List<AppModule> _mergeWithLocalSelection(List<AppModule> serverList) {
    // Load local saved (synchronously not possible). For simplicity here we just
    // return serverList and rely on call-site to re-save merged list after async load.
    return serverList;
  }
}
