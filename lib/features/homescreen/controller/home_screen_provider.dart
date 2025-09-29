import 'package:flutter/material.dart';
import '../../../service/StatsService.dart';

class HomeScreenProvider with ChangeNotifier {
  final StatsService _statsService = StatsService.instance;

  bool _isLoading = true;
  Map<String, dynamic> _stats = {
    'totalFiles': 0,
    'images': 0,
    'audio': 0,
    'videos': 0,
    'other': 0,
    'storageUsed': '0 B',
    'storageUsedBytes': 0,
  };
  String? _error;

  bool get isLoading => _isLoading;
  Map<String, dynamic> get stats => _stats;
  String? get error => _error;

  // Getters for individual stats
  int get totalFiles => _stats['totalFiles'] ?? 0;
  int get imageCount => _stats['images'] ?? 0;
  int get audioCount => _stats['audio'] ?? 0;
  int get videoCount => _stats['videos'] ?? 0;
  int get otherCount => _stats['other'] ?? 0;
  String get storageUsed => _stats['storageUsed'] ?? '0 B';

  Future<void> loadStats() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newStats = await _statsService.getFileStats();
      _stats = newStats;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshStats() async {
    await loadStats();
  }
}
