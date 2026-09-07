import '../../domain/entities/idea.dart';

class IdeaModel extends Idea {
  IdeaModel({
    required super.id,
    required super.title,
    required super.description,
    required super.category,
    required super.creator,
    required super.collaboratorsNeeded,
  });

  factory IdeaModel.fromJson(Map<String, dynamic> json) {
    return IdeaModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      category: json['category'],
      creator: json['creator'],
      collaboratorsNeeded: json['collaboratorsNeeded'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'creator': creator,
      'collaboratorsNeeded': collaboratorsNeeded,
    };
  }
}