// lib/models/menu_type.dart - UPDATED WITHOUT OPERATIONAL HOURS
import 'package:flutter/material.dart';

enum MenuType {
  breakfast,
  lunch,
  snacks;

  String get displayName {
    switch (this) {
      case MenuType.breakfast:
        return 'Breakfast';
      case MenuType.lunch:
        return 'Lunch';
      case MenuType.snacks:
        return 'Snacks';
    }
  }

  String get value {
    switch (this) {
      case MenuType.breakfast:
        return 'breakfast';
      case MenuType.lunch:
        return 'lunch';
      case MenuType.snacks:
        return 'snacks';
    }
  }

  IconData get icon {
    switch (this) {
      case MenuType.breakfast:
        return Icons.free_breakfast;
      case MenuType.lunch:
        return Icons.lunch_dining;
      case MenuType.snacks:
        return Icons.coffee;
    }
  }

  Color get color {
    switch (this) {
      case MenuType.breakfast:
        return Colors.orange;
      case MenuType.lunch:
        return Colors.green;
      case MenuType.snacks:
        return Colors.brown;
    }
  }

  static MenuType fromString(String value) {
    switch (value) {
      case 'breakfast':
        return MenuType.breakfast;
      case 'lunch':
        return MenuType.lunch;
      case 'snacks':
        return MenuType.snacks;
      default:
        return MenuType.breakfast;
    }
  }
}

class OperationalStatus {
  final MenuType menuType;
  final bool isEnabled;
  final DateTime lastUpdated;
  final int itemCount;
  final int availableItemCount;

  OperationalStatus({
    required this.menuType,
    required this.isEnabled,
    required this.lastUpdated,
    this.itemCount = 0,
    this.availableItemCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'menuType': menuType.value,
      'isEnabled': isEnabled,
      'lastUpdated': lastUpdated.toIso8601String(),
      'itemCount': itemCount,
      'availableItemCount': availableItemCount,
    };
  }

  factory OperationalStatus.fromMap(Map<String, dynamic> map) {
    return OperationalStatus(
      menuType: MenuType.fromString(map['menuType']),
      isEnabled: map['isEnabled'] ?? false,
      lastUpdated: DateTime.parse(map['lastUpdated']),
      itemCount: map['itemCount'] ?? 0,
      availableItemCount: map['availableItemCount'] ?? 0,
    );
  }

  OperationalStatus copyWith({
    MenuType? menuType,
    bool? isEnabled,
    DateTime? lastUpdated,
    int? itemCount,
    int? availableItemCount,
  }) {
    return OperationalStatus(
      menuType: menuType ?? this.menuType,
      isEnabled: isEnabled ?? this.isEnabled,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      itemCount: itemCount ?? this.itemCount,
      availableItemCount: availableItemCount ?? this.availableItemCount,
    );
  }

  bool get canShowToUsers => isEnabled;

  String get statusText {
    if (!isEnabled) return 'Disabled';
    return 'Enabled';
  }

  Color get statusColor {
    if (!isEnabled) return Colors.grey;
    return Colors.green;
  }
}