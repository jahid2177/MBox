class ViewerProfile {
  final String id;
  final String name;
  final String avatar;
  final bool isKids;
  const ViewerProfile({required this.id, required this.name, required this.avatar, required this.isKids});
  factory ViewerProfile.fromJson(Map<String, dynamic> data) => ViewerProfile(
    id: '${data['id'] ?? ''}', name: '${data['name'] ?? ''}',
    avatar: '${data['avatar'] ?? ''}', isKids: data['isKids'] == true,
  );
}

class AppUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final bool isPremium;
  final String activeProfileId;
  final List<ViewerProfile> profiles;
  const AppUser({required this.id, required this.name, required this.email,
    required this.role, this.isPremium = false, this.activeProfileId = '', this.profiles = const []});
  bool get isAdmin => role == 'admin';
  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: '${json['id'] ?? ''}', name: '${json['name'] ?? ''}', email: '${json['email'] ?? ''}',
    role: '${json['role'] ?? 'user'}', isPremium: json['isPremium'] == true,
    activeProfileId: '${json['activeProfileId'] ?? ''}',
    profiles: (json['profiles'] is List ? json['profiles'] as List : [])
        .whereType<Map>().map((e) => ViewerProfile.fromJson(Map<String, dynamic>.from(e))).toList(),
  );
}
