// lib/presentation/widgets/admin/menu_type_card.dart - UPDATED WITHOUT OPERATIONAL HOURS
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/menu_type.dart';

class MenuTypeCard extends StatefulWidget {
  final OperationalStatus status;
  final Function(bool) onToggle;
  final VoidCallback onForceEnable;

  const MenuTypeCard({
    Key? key,
    required this.status,
    required this.onToggle,
    required this.onForceEnable,
  }) : super(key: key);

  @override
  State<MenuTypeCard> createState() => _MenuTypeCardState();
}

class _MenuTypeCardState extends State<MenuTypeCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _animateToggle() async {
    setState(() {
      _isToggling = true;
    });
    
    await _animationController.forward();
    await _animationController.reverse();
    
    setState(() {
      _isToggling = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.status.statusColor.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.status.menuType.color.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildStatusSection(),
                const SizedBox(height: 16),
                _buildStatsSection(),
                const SizedBox(height: 16),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Menu type icon
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.status.menuType.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            widget.status.menuType.icon,
            color: widget.status.menuType.color,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        
        // Menu type info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.status.menuType.displayName,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Menu Control',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        
        // Main toggle switch
        Transform.scale(
          scale: 1.2,
          child: Switch(
            value: widget.status.isEnabled,
            onChanged: _isToggling ? null : (value) {
              _animateToggle();
              widget.onToggle(value);
            },
            activeColor: widget.status.menuType.color,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.status.statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.status.statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: widget.status.statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.status.statusColor.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          
          // Status text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.status.statusText,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: widget.status.statusColor,
                  ),
                ),
                Text(
                  widget.status.isEnabled 
                    ? 'Menu is visible to users'
                    : 'Menu is hidden from users',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.status.isEnabled 
                ? Colors.green.withOpacity(0.2)
                : Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.status.isEnabled ? 'ACTIVE' : 'INACTIVE',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: widget.status.isEnabled ? Colors.green : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Items',
            widget.status.itemCount.toString(),
            Icons.restaurant_menu,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Available',
            widget.status.availableItemCount.toString(),
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Out of Stock',
            (widget.status.itemCount - widget.status.availableItemCount).toString(),
            Icons.remove_circle,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Edit menu items button
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pushNamed(
                context, 
                '/admin/menu',
                arguments: {'menuType': widget.status.menuType},
              );
            },
            icon: const Icon(Icons.edit, size: 18),
            label: Text(
              'Edit Items',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.status.menuType.color,
              side: BorderSide(color: widget.status.menuType.color),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Quick enable button (if disabled)
        if (!widget.status.isEnabled)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: widget.onForceEnable,
              icon: const Icon(Icons.flash_on, size: 18),
              label: Text(
                'Quick Enable',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
      ],
    );
  }
}