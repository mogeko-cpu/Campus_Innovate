class Listing {
  final int id;
  final String title;
  final String description;
  final String category;
  final String creator;
  final int collaboratorsNeeded;

  const Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.creator,
    required this.collaboratorsNeeded,
  });
}