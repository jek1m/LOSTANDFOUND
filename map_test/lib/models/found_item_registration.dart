class FoundItemRegistration {
  const FoundItemRegistration({
    required this.itemName,
    required this.category,
    required this.foundAt,
    required this.foundPlace,
    required this.storagePlace,
    required this.description,
    required this.reporterName,
    required this.contact,
    required this.password,
    required this.createdAt,
    this.imagePath,
    this.latitude,
    this.longitude,
  });

  final String itemName;
  final String category;
  final DateTime foundAt;
  final String foundPlace;
  final String storagePlace;
  final String description;
  final String reporterName;
  final String contact;
  final String password;
  final DateTime createdAt;
  final String? imagePath;
  final double? latitude;
  final double? longitude;

  Map<String, dynamic> toMap() {
    return {
      'itemName': itemName,
      'category': category,
      'foundAt': foundAt.toIso8601String(),
      'foundPlace': foundPlace,
      'storagePlace': storagePlace,
      'description': description,
      'reporterName': reporterName,
      'contact': contact,
      'password': password,
      'createdAt': createdAt.toIso8601String(),
      'imagePath': imagePath,
      'latitude': latitude,
      'longitude': longitude,
      'status': 'registered',
    };
  }
}
