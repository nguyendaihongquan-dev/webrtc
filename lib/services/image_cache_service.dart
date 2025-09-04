import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';

/// Service for managing image cache operations
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  /// Get the total size of image cache in bytes
  Future<int> getCacheSizeInBytes() async {
    try {
      int totalSize = 0;

      // Get cache directory from path_provider
      final tempDir = await getTemporaryDirectory();

      // Check common cache directories
      final cacheDirs = [
        Directory(
          '${tempDir.path}/libCachedImageData',
        ), // cached_network_image cache
        Directory('${tempDir.path}/flutter_cache'), // Flutter cache
        Directory('${tempDir.path}/image_cache'), // General image cache
      ];

      for (final cacheDir in cacheDirs) {
        if (await cacheDir.exists()) {
          totalSize += await _calculateDirectorySize(cacheDir);
        }
      }

      // Also check Flutter's image cache in memory (estimate)
      final imageCache = PaintingBinding.instance.imageCache;
      final imageCacheCount = imageCache.currentSize;
      // Estimate ~50KB per cached image in memory
      totalSize += imageCacheCount * 50 * 1024;

      Logger.service(
        'ImageCacheService',
        'Total cache size: ${formatCacheSize(totalSize)} ($imageCacheCount images in memory)',
      );
      return totalSize;
    } catch (e) {
      Logger.error('Failed to calculate cache size', error: e);
      return 0;
    }
  }

  /// Calculate the size of a directory recursively
  Future<int> _calculateDirectorySize(Directory directory) async {
    int size = 0;
    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            size += stat.size.toInt();
          } catch (e) {
            // Skip files that can't be accessed
            Logger.warning('Could not access file: ${entity.path}');
          }
        }
      }
    } catch (e) {
      Logger.warning('Error calculating directory size: $e');
    }
    return size;
  }

  /// Format cache size for display
  String formatCacheSize(int bytes) {
    if (bytes == 0) return "0.00B";

    const suffixes = ['B', 'KB', 'MB', 'GB'];
    final i = (log(bytes) / log(1024)).floor();
    final size = bytes / pow(1024, i);

    return '${size.toStringAsFixed(2)}${suffixes[i]}';
  }

  /// Get formatted cache size string
  Future<String> getFormattedCacheSize() async {
    final sizeInBytes = await getCacheSizeInBytes();
    return formatCacheSize(sizeInBytes);
  }

  /// Clear all image cache
  Future<bool> clearImageCache() async {
    try {
      Logger.service('ImageCacheService', 'Starting to clear image cache');

      // Clear DefaultCacheManager cache (used by cached_network_image)
      final cacheManager = DefaultCacheManager();
      await cacheManager.emptyCache();

      // Clear Flutter's image cache
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // Clear cache directories
      final tempDir = await getTemporaryDirectory();
      final cacheDirs = [
        Directory('${tempDir.path}/libCachedImageData'),
        Directory('${tempDir.path}/flutter_cache'),
        Directory('${tempDir.path}/image_cache'),
      ];

      for (final cacheDir in cacheDirs) {
        try {
          if (await cacheDir.exists()) {
            await cacheDir.delete(recursive: true);
            Logger.service(
              'ImageCacheService',
              'Cleared cache directory: ${cacheDir.path}',
            );
          }
        } catch (e) {
          Logger.warning(
            'Could not clear cache directory ${cacheDir.path}: $e',
          );
        }
      }

      Logger.service('ImageCacheService', 'Image cache cleared successfully');
      return true;
    } catch (e) {
      Logger.error('Failed to clear image cache', error: e);
      return false;
    }
  }

  /// Clear cache and return new cache size
  Future<String> clearCacheAndGetNewSize() async {
    final success = await clearImageCache();
    if (success) {
      // Wait a bit for the cache to be actually cleared
      await Future.delayed(const Duration(milliseconds: 500));
      return await getFormattedCacheSize();
    } else {
      // Return current size if clearing failed
      return await getFormattedCacheSize();
    }
  }

  /// Check if cache size is significant (> 1MB)
  Future<bool> isCacheSizeSignificant() async {
    final sizeInBytes = await getCacheSizeInBytes();
    return sizeInBytes > 1024 * 1024; // > 1MB
  }
}
