class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String imageUrl; // Placeholder for now
  final bool isAlcohol;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.imageUrl,
    this.isAlcohol = false,
  });

  // Factory for JSON serialization later
  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      name: json['name'] ?? 'Unknown',
      description: json['description'] ?? '',
      price: ((json['price'] as num?)?.toDouble() ?? 0.0),
      category: json['category'] ?? 'Main',
      imageUrl: json['imageUrl'] ?? '',
      isAlcohol: json['isAlcohol'] == true,
    );
  }
}
