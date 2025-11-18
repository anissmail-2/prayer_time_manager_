import 'package:flutter/material.dart';
import '../models/enhanced_task.dart';
import '../core/services/space_service.dart';
import '../core/theme/app_theme.dart';
import '../widgets/enhanced_item_form.dart';

class AddEditSpaceItemScreen extends StatefulWidget {
  final String spaceId;
  final EnhancedTask? editingItem;
  final String spaceName;
  final Color spaceColor;

  const AddEditSpaceItemScreen({
    super.key,
    required this.spaceId,
    required this.spaceName,
    required this.spaceColor,
    this.editingItem,
  });

  @override
  State<AddEditSpaceItemScreen> createState() => _AddEditSpaceItemScreenState();
}

class _AddEditSpaceItemScreenState extends State<AddEditSpaceItemScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: AppTheme.animationMedium,
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: AppTheme.animationCurve,
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(EnhancedTask item) async {
    try {
      if (widget.editingItem != null) {
        await SpaceService.updateEnhancedTask(item);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated "${item.title}"')),
        );
      } else {
        await SpaceService.createEnhancedTask(item);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created "${item.title}"'),
            action: item.hasTimeBlock ? SnackBarAction(
              label: 'Push to Timeline',
              onPressed: () {
                // Handle push to timeline
                Navigator.pop(context, {'item': item, 'pushToTimeline': true});
              },
            ) : null,
          ),
        );
      }
      
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving item: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.editingItem != null ? 'Edit Item' : 'Create New Item',
              style: AppTheme.headlineSmall.copyWith(
                color: isDark ? Colors.white : AppTheme.primary,
              ),
            ),
            Text(
              'in ${widget.spaceName}',
              style: AppTheme.bodySmall.copyWith(
                color: widget.spaceColor.withOpacity(0.8),
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(AppTheme.space8),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : AppTheme.primary).withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(
              Icons.arrow_back,
              color: isDark ? Colors.white : AppTheme.primary,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.space16),
          child: EnhancedItemForm(
            spaceId: widget.spaceId,
            editingItem: widget.editingItem,
            onSubmit: _handleSubmit,
          ),
        ),
      ),
    );
  }
}