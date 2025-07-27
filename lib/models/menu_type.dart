// lib/models/menu_type.dart
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

class MenuSchedule {
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final MenuType menuType;

  MenuSchedule({
    required this.startTime,
    required this.endTime,
    required this.menuType,
  });

  factory MenuSchedule.defaultSchedule(MenuType menuType) {
    switch (menuType) {
      case MenuType.breakfast:
        return MenuSchedule(
          startTime: const TimeOfDay(hour: 8, minute: 30),
          endTime: const TimeOfDay(hour: 10, minute: 0),
          menuType: menuType,
        );
      case MenuType.lunch:
        return MenuSchedule(
          startTime: const TimeOfDay(hour: 11, minute: 0),
          endTime: const TimeOfDay(hour: 15, minute: 0),
          menuType: menuType,
        );
      case MenuType.snacks:
        return MenuSchedule(
          startTime: const TimeOfDay(hour: 15, minute: 30),
          endTime: const TimeOfDay(hour: 18, minute: 0),
          menuType: menuType,
        );
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'startTime': '${startTime.hour}:${startTime.minute}',
      'endTime': '${endTime.hour}:${endTime.minute}',
      'menuType': menuType.value,
    };
  }

  factory MenuSchedule.fromMap(Map<String, dynamic> map) {
    final startTimeParts = map['startTime'].split(':');
    final endTimeParts = map['endTime'].split(':');
    
    return MenuSchedule(
      startTime: TimeOfDay(
        hour: int.parse(startTimeParts[0]),
        minute: int.parse(startTimeParts[1]),
      ),
      endTime: TimeOfDay(
        hour: int.parse(endTimeParts[0]),
        minute: int.parse(endTimeParts[1]),
      ),
      menuType: MenuType.fromString(map['menuType']),
    );
  }

  bool isCurrentlyActive() {
    final now = TimeOfDay.now();
    return _isTimeInRange(now, startTime, endTime);
  }

  bool _isTimeInRange(TimeOfDay current, TimeOfDay start, TimeOfDay end) {
    final currentMinutes = current.hour * 60 + current.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    
    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }

  String getFormattedTimeRange() {
    return '${_formatTime(startTime)} - ${_formatTime(endTime)}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}

class OperationalStatus {
  final MenuType menuType;
  final bool isEnabled;
  final bool isCurrentlyActive;
  final MenuSchedule schedule;
  final DateTime lastUpdated;
  final int itemCount;
  final int availableItemCount;

  OperationalStatus({
    required this.menuType,
    required this.isEnabled,
    required this.isCurrentlyActive,
    required this.schedule,
    required this.lastUpdated,
    this.itemCount = 0,
    this.availableItemCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'menuType': menuType.value,
      'isEnabled': isEnabled,
      'schedule': schedule.toMap(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'itemCount': itemCount,
      'availableItemCount': availableItemCount,
    };
  }

  factory OperationalStatus.fromMap(Map<String, dynamic> map) {
    return OperationalStatus(
      menuType: MenuType.fromString(map['menuType']),
      isEnabled: map['isEnabled'] ?? false,
      isCurrentlyActive: false, // Will be calculated
      schedule: MenuSchedule.fromMap(map['schedule']),
      lastUpdated: DateTime.parse(map['lastUpdated']),
      itemCount: map['itemCount'] ?? 0,
      availableItemCount: map['availableItemCount'] ?? 0,
    );
  }

  OperationalStatus copyWith({
    MenuType? menuType,
    bool? isEnabled,
    bool? isCurrentlyActive,
    MenuSchedule? schedule,
    DateTime? lastUpdated,
    int? itemCount,
    int? availableItemCount,
  }) {
    return OperationalStatus(
      menuType: menuType ?? this.menuType,
      isEnabled: isEnabled ?? this.isEnabled,
      isCurrentlyActive: isCurrentlyActive ?? this.isCurrentlyActive,
      schedule: schedule ?? this.schedule,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      itemCount: itemCount ?? this.itemCount,
      availableItemCount: availableItemCount ?? this.availableItemCount,
    );
  }

  bool get canShowToUsers => isEnabled && isCurrentlyActive;

  String get statusText {
    if (!isEnabled) return 'Disabled';
    if (!isCurrentlyActive) return 'Not in operating hours';
    return 'Active';
  }

  Color get statusColor {
    if (!isEnabled) return Colors.grey;
    if (!isCurrentlyActive) return Colors.orange;
    return Colors.green;
  }
}