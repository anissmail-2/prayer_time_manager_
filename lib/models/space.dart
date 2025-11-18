import 'package:cloud_firestore/cloud_firestore.dart';

class Space {
  final String id;
  final String name;
  final String? description;
  final String? color; // Hex color for UI
  final DateTime createdAt;
  final DateTime? updatedAt;
  final SpaceStatus status;
  final List<String> itemIds; // References to items/ideas
  final String? parentSpaceId; // For sub-spaces
  final List<String> subSpaceIds; // Child spaces
  final Map<String, dynamic>? metadata; // Flexible additional data
  
  Space({
    required this.id,
    required this.name,
    this.description,
    this.color,
    required this.createdAt,
    this.updatedAt,
    this.status = SpaceStatus.active,
    List<String>? itemIds,
    this.parentSpaceId,
    List<String>? subSpaceIds,
    this.metadata,
  }) : itemIds = itemIds ?? [],
       subSpaceIds = subSpaceIds ?? [];
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String() ?? createdAt.toIso8601String(),
      'status': status.index,
      'itemIds': itemIds,
      'parentSpaceId': parentSpaceId,
      'subSpaceIds': subSpaceIds,
      'metadata': metadata,
    };
  }
  
  // Helper method to parse dates from either String or Timestamp
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.parse(value);
    } else if (value is DateTime) {
      return value;
    }
    return null;
  }

  factory Space.fromJson(Map<String, dynamic> json) {
    return Space(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      color: json['color'],
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updatedAt']),
      status: SpaceStatus.values[json['status'] ?? 0],
      itemIds: List<String>.from(json['itemIds'] ?? json['taskIds'] ?? []), // Support old taskIds key
      parentSpaceId: json['parentSpaceId'],
      subSpaceIds: List<String>.from(json['subSpaceIds'] ?? []),
      metadata: json['metadata'],
    );
  }
  
  Space copyWith({
    String? id,
    String? name,
    String? description,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    SpaceStatus? status,
    List<String>? itemIds,
    String? parentSpaceId,
    List<String>? subSpaceIds,
    Map<String, dynamic>? metadata,
  }) {
    return Space(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      status: status ?? this.status,
      itemIds: itemIds ?? this.itemIds,
      parentSpaceId: parentSpaceId ?? this.parentSpaceId,
      subSpaceIds: subSpaceIds ?? this.subSpaceIds,
      metadata: metadata ?? this.metadata,
    );
  }
}

enum SpaceStatus {
  active,
  archived,
}