import 'package:equatable/equatable.dart';

class WorkCategory extends Equatable {
  final String id;
  final String name;
  final int order;
  final bool isActive;

  const WorkCategory({
    required this.id,
    required this.name,
    required this.order,
    this.isActive = true,
  });

  WorkCategory copyWith({String? id, String? name, int? order, bool? isActive}) {
    return WorkCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
    );
  }

  factory WorkCategory.fromMap(String id, Map<String, dynamic> map) {
    return WorkCategory(
      id: id,
      name: (map['name'] ?? '').toString(),
      order: (map['order'] ?? 0) is int ? map['order'] as int : int.tryParse('${map['order']}') ?? 0,
      isActive: (map['isActive'] ?? true) == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'order': order,
      'isActive': isActive,
    };
  }

  @override
  List<Object?> get props => [id, name, order, isActive];
}
