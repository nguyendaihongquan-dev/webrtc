import 'dart:convert';

class AppModule {
  String sid;
  String name;
  String desc;
  int status; // 0=disabled, 1=optional, 2=mandatory
  bool checked;

  AppModule({
    required this.sid,
    required this.name,
    required this.desc,
    required this.status,
    required this.checked,
  });

  factory AppModule.fromJson(Map<String, dynamic> json) {
    return AppModule(
      sid: json['sid']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      desc: json['desc']?.toString() ?? '',
      status: (json['status'] is int)
          ? json['status'] as int
          : int.tryParse(json['status']?.toString() ?? '0') ?? 0,
      checked: json['checked'] == true || json['checked'] == 1 || json['checked'] == 'true',
    );
  }

  Map<String, dynamic> toJson() => {
        'sid': sid,
        'name': name,
        'desc': desc,
        'status': status,
        'checked': checked,
      };

  static List<AppModule> listFromJson(dynamic data) {
    if (data == null) return [];
    if (data is String) {
      try {
        final parsed = jsonDecode(data);
        if (parsed is List) {
          return parsed.map((e) => AppModule.fromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
      return [];
    }
    if (data is List) {
      return data.map((e) => AppModule.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }
}

