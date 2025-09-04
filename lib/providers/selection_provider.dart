import 'package:flutter/foundation.dart';

class SelectedIds extends ChangeNotifier {
  final Set<String> _ids = <String>{};

  bool contains(String id) => _ids.contains(id);

  int get length => _ids.length;

  Set<String> get ids => Set.unmodifiable(_ids);

  void toggle(String id) {
    if (_ids.contains(id)) {
      _ids.remove(id);
    } else {
      _ids.add(id);
    }
    notifyListeners();
  }

  void clear() {
    if (_ids.isEmpty) return;
    _ids.clear();
    notifyListeners();
  }
}
