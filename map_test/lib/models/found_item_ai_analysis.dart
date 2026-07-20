class FoundItemAiAnalysis {
  const FoundItemAiAnalysis({
    required this.itemName,
    required this.category,
    required this.description,
  });

  final String itemName;
  final String category;
  final String description;

  factory FoundItemAiAnalysis.fromJson(Map<String, dynamic> json) {
    return FoundItemAiAnalysis(
      itemName: (json['itemName'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
    );
  }
}
