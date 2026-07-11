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

  // fdPrdtNm
  final String itemName;

  // prdtClNmMg
  final String category;

  // fdYmd
  final DateTime foundAt;

  // fndPlace
  final String foundPlace;

  // fndDescription
  final String description;

  // tel
  final String contact;

  // password
  final String password;

  final double? latitude;
  final double? longitude;

  final String sido;
  final String sigungu;
  final String eupmyeondong;
}
