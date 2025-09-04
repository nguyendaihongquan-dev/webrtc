import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../utils/logger.dart';

/// Attachment uploader to mirror Android WKUploader behavior
class AttachmentUploader {
  AttachmentUploader._();
  static final AttachmentUploader _instance = AttachmentUploader._();
  factory AttachmentUploader() => _instance;

  Future<Dio?> _createDio() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token =
          prefs.getString(WKConstants.imTokenKey) ??
          prefs.getString(WKConstants.tokenKey) ??
          '';

      final dio = Dio();
      final base = WKApiConfig.baseUrl.isNotEmpty
          ? WKApiConfig.baseUrl
          : '${WKApiConfig.defaultBaseUrl}/v1/';
      dio.options.baseUrl = base;
      dio.options.headers = {
        'Content-Type': 'application/json',
        'token': token,
        'package': 'com.test.demo',
        'os': 'iOS',
        'appid': 'wukongchat',
        'model': 'flutter_app',
        'version': '1.0',
      };
      return dio;
    } catch (e) {
      Logger.error('AttachmentUploader: Failed to create Dio', error: e);
      return null;
    }
  }

  /// Get upload URL for a given local file
  Future<_UploadTicket?> getUploadFileUrl(
    String channelId,
    int channelType,
    String localPath,
  ) async {
    try {
      final dio = await _createDio();
      if (dio == null) return null;

      final file = File(localPath);
      if (!await file.exists()) {
        Logger.error('AttachmentUploader: File not found $localPath');
        return null;
      }
      final name = file.path.split('/').last;
      final ext = name.contains('.') ? name.split('.').last : 'dat';
      final millis = DateTime.now().millisecondsSinceEpoch;
      final path = '/$channelType/$channelId/$millis.$ext';

      // Android sample hits: file/upload?type=chat&path=<path>
      final resp = await dio.get(
        'file/upload',
        queryParameters: {'type': 'chat', 'path': path},
      );

      if (resp.statusCode == 200 && resp.data is Map) {
        final data = (resp.data as Map).cast<String, dynamic>();
        final url = data['url'] as String?;
        if (url != null && url.isNotEmpty) {
          return _UploadTicket(uploadUrl: url, serverPath: path);
        }
      }

      Logger.warning(
        'AttachmentUploader: getUploadFileUrl unexpected response ${resp.statusCode}',
      );
      return null;
    } catch (e) {
      Logger.error('AttachmentUploader: getUploadFileUrl error', error: e);
      return null;
    }
  }

  /// Upload file to given uploadUrl using multipart form
  Future<String?> upload(String uploadUrl, String filePath) async {
    try {
      print('🎭 UPLOADER: Creating Dio client');
      final dio = await _createDio();
      if (dio == null) {
        print('🎭 UPLOADER: ❌ Failed to create Dio client');
        return null;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        print('🎭 UPLOADER: ❌ File not found: $filePath');
        Logger.error('AttachmentUploader: File not found $filePath');
        return null;
      }

      final fileSize = await file.length();
      print('🎭 UPLOADER: File size: ${fileSize} bytes');
      print('🎭 UPLOADER: Upload URL: $uploadUrl');
      print('🎭 UPLOADER: File path: $filePath');

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      print('🎭 UPLOADER: Form data created, starting upload...');
      print('🎭 UPLOADER: Headers: ${dio.options.headers}');

      // Note: uploadUrl may be absolute; if so, use dio.fetch via fullUrl
      final resp = await dio.postUri(Uri.parse(uploadUrl), data: formData);

      print('🎭 UPLOADER: Response status: ${resp.statusCode}');
      print('🎭 UPLOADER: Response data: ${resp.data}');
      print('🎭 UPLOADER: Response headers: ${resp.headers}');

      if (resp.statusCode == 200) {
        if (resp.data is Map) {
          final data = (resp.data as Map).cast<String, dynamic>();
          print('🎭 UPLOADER: Response data keys: ${data.keys.toList()}');
          print('🎭 UPLOADER: Full response data: $data');

          // Check status first
          final status = data['status'];
          print('🎭 UPLOADER: Status value: $status');

          // Try different possible field names for the uploaded path
          String? path = data['path'] as String?;
          path ??= data['url'] as String?;
          path ??= data['file_path'] as String?;
          path ??= data['filepath'] as String?;
          path ??= data['avatar'] as String?;
          path ??= data['avatar_url'] as String?;
          path ??= data['data'] as String?; // Sometimes path is in 'data' field

          if (path != null && path.isNotEmpty) {
            print('🎭 UPLOADER: ✅ Upload successful, path: $path');
            return path;
          } else {
            // If status indicates success but no path, maybe we need to construct it
            if (status == 'success' ||
                status == 'ok' ||
                status == 200 ||
                status == '200') {
              print(
                '🎭 UPLOADER: ✅ Status indicates success but no path returned',
              );
              print(
                '🎭 UPLOADER: Returning success indicator for path construction',
              );
              return 'SUCCESS'; // Return a success indicator
            }
            print('🎭 UPLOADER: ❌ No recognized path field in response data');
            print('🎭 UPLOADER: ❌ Available fields: ${data.keys.join(', ')}');
          }
        } else if (resp.data is String) {
          // Some APIs might return just the path as a string
          final pathString = resp.data as String;
          print('🎭 UPLOADER: Response is string: $pathString');
          if (pathString.isNotEmpty) {
            print('🎭 UPLOADER: ✅ Upload successful, path: $pathString');
            return pathString;
          }
        } else {
          print(
            '🎭 UPLOADER: ❌ Response data is not Map or String: ${resp.data.runtimeType}',
          );
        }
      } else {
        print('🎭 UPLOADER: ❌ Unexpected response status: ${resp.statusCode}');
      }

      Logger.warning(
        'AttachmentUploader: upload unexpected response ${resp.statusCode}',
      );
      return null;
    } catch (e, stackTrace) {
      print('🎭 UPLOADER: ❌ Upload exception: $e');
      print('🎭 UPLOADER: ❌ Stack trace: $stackTrace');
      Logger.error('AttachmentUploader: upload error', error: e);
      return null;
    }
  }
}

class _UploadTicket {
  final String uploadUrl;
  final String serverPath;
  _UploadTicket({required this.uploadUrl, required this.serverPath});
}
