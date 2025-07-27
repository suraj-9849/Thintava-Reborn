// lib/presentation/widgets/admin/operational_hours_widget.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/menu_type.dart';

class OperationalHoursWidget extends StatefulWidget {
  const OperationalHoursWidget({Key? key}) : super(key: key);

  @override
  State<OperationalHoursWidget> createState() => _OperationalHoursWidgetState();
}

class _OperationalHoursWidgetState extends State<OperationalHoursWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          if (_isExpanded) _buildExpandedContent(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return InkWell(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.access_time,
                color: Colors.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Operating Hours',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    _getCurrentTimeStatus(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            _buildCurrentTimeChip(),
            
            const SizedBox(width: 8),
            
            Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTimeChip() {
    final now = TimeOfDay.now();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        now.format(context),
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),
          
          // Today's schedule header
          Row(
            children: [
              Icon(
                Icons.today,
                color: Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "Today's Schedule",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Menu schedules
          ...MenuType.values.map((menuType) => _buildScheduleItem(menuType)),
          
          const SizedBox(height: 16),
          
          // Quick info
          _buildQuickInfo(),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(MenuType menuType) {
    final schedule = MenuSchedule.defaultSchedule(menuType);
    final isCurrentlyActive = schedule.isCurrentlyActive();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentlyActive 
          ? menuType.color.withOpacity(0.1)
          : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentlyActive 
            ? menuType.color.withOpacity(0.3)
            : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Menu icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: menuType.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              menuType.icon,
              color: menuType.color,
              size: 18,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Menu name and time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  menuType.displayName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  schedule.getFormattedTimeRange(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isCurrentlyActive ? Colors.green : Colors.grey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isCurrentlyActive ? 'Active' : 'Inactive',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.amber[700],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Info',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Admins can force enable any menu outside operating hours. Users will only see enabled menus during their respective time slots.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[700],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentTimeStatus() {
    final now = TimeOfDay.now();
    
    for (MenuType menuType in MenuType.values) {
      final schedule = MenuSchedule.defaultSchedule(menuType);
      if (schedule.isCurrentlyActive()) {
        return '${menuType.displayName} time is active';
      }
    }
    
    // Find next menu
    MenuSchedule? nextSchedule;
    int? nextMinutes;
    final currentMinutes = now.hour * 60 + now.minute;
    
    for (MenuType menuType in MenuType.values) {
      final schedule = MenuSchedule.defaultSchedule(menuType);
      final startMinutes = schedule.startTime.hour * 60 + schedule.startTime.minute;
      
      if (startMinutes > currentMinutes) {
        if (nextMinutes == null || startMinutes < nextMinutes) {
          nextMinutes = startMinutes;
          nextSchedule = schedule;
        }
      }
    }
    
    if (nextSchedule != null) {
      return 'Next: ${nextSchedule.menuType.displayName} at ${nextSchedule.startTime.format(context)}';
    }
    
    // No more menus today, show tomorrow's first menu
    final breakfastSchedule = MenuSchedule.defaultSchedule(MenuType.breakfast);
    return 'Next: ${breakfastSchedule.menuType.displayName} tomorrow at ${breakfastSchedule.startTime.format(context)}';
  }
}