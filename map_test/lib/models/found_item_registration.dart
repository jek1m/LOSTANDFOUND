class FoundItemRegistration {
  const FoundItemRegistration({
    required this.itemName,
    required this.category,
    required this.foundAt,
    required this.foundPlace,
    required this.description,
    required this.contact,
    required this.password,
    required this.sido,
    required this.sigungu,
    required this.eupmyeondong,
    this.latitude,
    this.longitude,
  });

  final String itemName;
  final String category;
  final DateTime foundAt;
  final String foundPlace;
  final String description;
  final String contact;
  final String password;
  final double? latitude;
  final double? longitude;
  final String sido;
  final String sigungu;
  final String eupmyeondong;
}
