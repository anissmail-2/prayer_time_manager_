import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/services/space_service.dart';
import '../core/services/prayer_time_service.dart';
import '../models/space.dart';
import '../models/enhanced_task.dart';
import '../models/task.dart';
import '../widgets/enhanced_item_form.dart';
import '../widgets/task_details_dialog.dart';
import 'add_edit_space_item_screen.dart';

class MobileSpacesScreen extends StatefulWidget {
  final VoidCallback? onNavigateToTasks;
  
  const MobileSpacesScreen({
    super.key,
    this.onNavigateToTasks,
  });

  @override
  State<MobileSpacesScreen> createState() => _MobileSpacesScreenState();
}

class _MobileSpacesScreenState extends State<MobileSpacesScreen> {
  List<Space> _spaces = [];
  List<EnhancedTask> _allIdeas = [];
  Space? _selectedSpace;
  bool _isLoading = true;
  bool _showSpacesList = true; // Start by showing spaces list
  final TextEditingController _quickAddController = TextEditingController();
  Map<String, String> _cachedPrayerTimes = {};
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  @override
  void dispose() {
    _quickAddController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load spaces and ideas
      final spaces = await SpaceService.getAllSpaces();
      final ideas = await SpaceService.getAllEnhancedTasks();
      
      // Load prayer times for calculating actual times
      try {
        _cachedPrayerTimes = await PrayerTimeService.getPrayerTimes();
      } catch (e) {
        // If prayer times fail to load, we'll fall back to relative display
        debugPrint('Failed to load prayer times: $e');
      }
      
      // Don't create default inbox space - let user create their own spaces

      if (!mounted) return;
      setState(() {
        _spaces = spaces;
        _allIdeas = ideas;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading spaces: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
  
  List<EnhancedTask> _getSpaceIdeas() {
    if (_selectedSpace == null) return [];
    return _allIdeas.where((idea) => idea.spaceId == _selectedSpace!.id).toList();
  }
  
  List<Space> _getSubSpaces(String parentId) {
    return _spaces.where((space) => space.parentSpaceId == parentId).toList();
  }
  
  List<Space> _getRootSpaces() {
    return _spaces.where((space) => space.parentSpaceId == null).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    
    if (isTablet) {
      return _buildTabletLayout();
    } else {
      return _buildPhoneLayout();
    }
  }
  
  Widget _buildPhoneLayout() {
    if (_showSpacesList || _selectedSpace == null) {
      // Show spaces list
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor(context),
        appBar: AppBar(
          backgroundColor: AppTheme.surfaceColor(context),
          elevation: 0,
          title: Text(
            'Spaces',
            style: AppTheme.headlineSmall.copyWith(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.add_circle, color: AppTheme.primary),
              onPressed: _showCreateSpaceDialog,
            ),
          ],
        ),
        body: _buildSpacesList(),
      );
    } else {
      // Show selected space content
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor(context),
        appBar: AppBar(
          backgroundColor: AppTheme.surfaceColor(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppTheme.textPrimaryColor(context)),
            onPressed: () {
              setState(() {
                // If viewing a sub-space, go back to parent
                if (_selectedSpace?.parentSpaceId != null) {
                  final parentSpace = _spaces.firstWhere(
                    (s) => s.id == _selectedSpace!.parentSpaceId,
                    orElse: () => _selectedSpace!,
                  );
                  _selectedSpace = parentSpace;
                } else {
                  // Otherwise go back to spaces list
                  _selectedSpace = null;
                  _showSpacesList = true;
                }
              });
            },
          ),
          title: Text(
            _selectedSpace?.name ?? 'Space',
            style: AppTheme.headlineSmall.copyWith(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            if (_selectedSpace != null)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: AppTheme.primary),
                onSelected: (value) => _handleSpaceMenuAction(value, _selectedSpace!),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Edit Space'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'create_subspace',
                    child: Row(
                      children: [
                        Icon(Icons.create_new_folder, size: 18),
                        SizedBox(width: 8),
                        Text('Create Sub-space'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18),
                        SizedBox(width: 8),
                        Text('Delete Space'),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: _buildSpaceContent(),
      );
    }
  }
  
  Widget _buildTabletLayout() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: Row(
        children: [
          // Space list sidebar
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              border: Border(
                right: BorderSide(color: AppTheme.borderColor(context)),
              ),
            ),
            child: Column(
              children: [
                _buildSpaceHeader(),
                Expanded(child: _buildSpacesList()),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: _selectedSpace != null
                ? _buildSpaceContent()
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 64,
                          color: AppTheme.textTertiaryColor(context),
                        ),
                        const SizedBox(height: AppTheme.space16),
                        Text(
                          'Select a space to view items',
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textSecondaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSpaceHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor(context)),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Spaces',
            style: AppTheme.headlineMedium.copyWith(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.add_circle, color: AppTheme.primary),
            onPressed: _showCreateSpaceDialog,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSpacesList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final rootSpaces = _getRootSpaces();
    
    if (rootSpaces.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 64,
              color: AppTheme.textTertiaryColor(context),
            ),
            const SizedBox(height: AppTheme.space16),
            Text(
              'No spaces yet',
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            ElevatedButton.icon(
              onPressed: _showCreateSpaceDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Space'),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.space16),
      itemCount: rootSpaces.length,
      itemBuilder: (context, index) {
        final space = rootSpaces[index];
        return _buildSpaceCard(space, 0);
      },
    );
  }
  
  Widget _buildSpaceCard(Space space, int depth) {
    final ideaCount = _allIdeas.where((idea) => idea.spaceId == space.id).length;
    final subSpaces = _getSubSpaces(space.id);
    final isTablet = MediaQuery.of(context).size.width > 600;
    
    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(
            left: depth * 20.0,
            bottom: AppTheme.space12,
          ),
          child: Material(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            elevation: 2,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedSpace = space;
                  if (!isTablet) {
                    _showSpacesList = false;
                  }
                });
              },
              onLongPress: () => _showSpaceOptionsMenu(space),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.space16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getSpaceColor(space.color).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Icon(
                        Icons.folder,
                        color: _getSpaceColor(space.color),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            space.name,
                            style: AppTheme.bodyLarge.copyWith(
                              color: AppTheme.textPrimaryColor(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (space.description != null) ...[
                            const SizedBox(height: AppTheme.space4),
                            Text(
                              space.description!,
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondaryColor(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: AppTheme.space4),
                          FutureBuilder<int>(
                            future: SpaceService.getSpaceItemCount(space.id, includeSubSpaces: true),
                            builder: (context, snapshot) {
                              final totalItems = snapshot.data ?? ideaCount;
                              return Row(
                                children: [
                                  Icon(
                                    Icons.list,
                                    size: 16,
                                    color: AppTheme.textTertiaryColor(context),
                                  ),
                                  const SizedBox(width: AppTheme.space4),
                                  Text(
                                    totalItems == ideaCount
                                        ? '$ideaCount items'
                                        : '$ideaCount items ($totalItems total)',
                                    style: AppTheme.bodySmall.copyWith(
                                      color: AppTheme.textTertiaryColor(context),
                                    ),
                                  ),
                                  if (subSpaces.isNotEmpty) ...[
                                    const SizedBox(width: AppTheme.space12),
                                    Icon(
                                      Icons.folder_open,
                                      size: 16,
                                      color: AppTheme.textTertiaryColor(context),
                                    ),
                                    const SizedBox(width: AppTheme.space4),
                                    Text(
                                      '${subSpaces.length} sub-spaces',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.textTertiaryColor(context),
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: AppTheme.textSecondaryColor(context)),
                      onSelected: (value) => _handleSpaceMenuAction(value, space),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'create_subspace',
                          child: Row(
                            children: [
                              Icon(Icons.create_new_folder, size: 18),
                              SizedBox(width: 8),
                              Text('Create Sub-space'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: AppTheme.error),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: AppTheme.error)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Show sub-spaces
        ...subSpaces.map((subSpace) => _buildSpaceCard(subSpace, depth + 1)),
      ],
    );
  }
  
  Widget _buildSpaceContent() {
    if (_selectedSpace == null) {
      return const SizedBox();
    }
    
    final spaceIdeas = _getSpaceIdeas();
    final subSpaces = _getSubSpaces(_selectedSpace!.id);
    
    return Column(
      children: [
        // Space info header with breadcrumb and sub-spaces
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            border: Border(
              bottom: BorderSide(color: AppTheme.borderColor(context)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Breadcrumb navigation
              if (_selectedSpace?.parentSpaceId != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space16,
                    vertical: AppTheme.space8,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _buildBreadcrumb(_selectedSpace!),
                    ),
                  ),
                ),
              // Sub-spaces section
              if (subSpaces.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(AppTheme.space16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sub-spaces',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondaryColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space8),
                      Wrap(
                        spacing: AppTheme.space8,
                        runSpacing: AppTheme.space8,
                        children: subSpaces.map((subSpace) {
                          return ActionChip(
                            label: Text(subSpace.name),
                            avatar: Icon(
                              Icons.folder_outlined,
                              size: 16,
                              color: _getSpaceColor(subSpace.color),
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedSpace = subSpace;
                              });
                            },
                            backgroundColor: _getSpaceColor(subSpace.color).withValues(alpha: 0.1),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        
        // Quick add section
        Container(
          padding: const EdgeInsets.all(AppTheme.space16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            border: Border(
              bottom: BorderSide(color: AppTheme.borderColor(context)),
            ),
          ),
          child: Row(
            children: [
              // Quick add text field for simple capture
              Expanded(
                child: TextField(
                  controller: _quickAddController,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Quick add item...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).hintColor,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      borderSide: BorderSide(color: AppTheme.borderColor(context)),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.add, color: AppTheme.primary),
                      onPressed: _quickAddIdea,
                    ),
                  ),
                  onSubmitted: (_) => _quickAddIdea(),
                ),
              ),
              const SizedBox(width: AppTheme.space8),
              // Detailed add button
              ElevatedButton.icon(
                onPressed: _showDetailedAddDialog,
                icon: const Icon(Icons.add_task),
                label: const Text('Detailed'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space16,
                    vertical: AppTheme.space12,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Idea list
        Expanded(
          child: spaceIdeas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lightbulb_outline, size: 48, color: AppTheme.textTertiaryColor(context)),
                      const SizedBox(height: AppTheme.space16),
                      Text(
                        'No items in this space',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ),
                      const SizedBox(height: AppTheme.space8),
                      Text(
                        'Add items quickly with just a name!',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textTertiaryColor(context),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppTheme.space16),
                  itemCount: spaceIdeas.length,
                  itemBuilder: (context, index) {
                    final idea = spaceIdeas[index];
                    return _buildIdeaCard(idea);
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildIdeaCard(EnhancedTask idea) {
    final hasCompleteTimeBlock = idea.hasTimeBlock;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.space12),
      child: Material(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        elevation: 1,
        child: InkWell(
          onTap: () => _showIdeaDetails(idea),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.space16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Priority indicator
                    Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getPriorityColor(idea.priority),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppTheme.space12),
                    
                    // Idea content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  idea.title,
                                  style: AppTheme.bodyLarge.copyWith(
                                    color: AppTheme.textPrimaryColor(context),
                                    fontWeight: FontWeight.w500,
                                    decoration: idea.status == TaskStatus.done 
                                        ? TextDecoration.lineThrough 
                                        : null,
                                  ),
                                ),
                              ),
                              if (idea.isScheduled) 
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: hasCompleteTimeBlock ? AppTheme.success : AppTheme.warning,
                                ),
                            ],
                          ),
                          if (idea.description != null && idea.description!.isNotEmpty) ...[
                            const SizedBox(height: AppTheme.space4),
                            Text(
                              idea.description!,
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondaryColor(context),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (idea.isScheduled) ...[
                            const SizedBox(height: AppTheme.space4),
                            Text(
                              _getScheduleDisplayText(idea),
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textTertiaryColor(context),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          if (idea.tags.isNotEmpty) ...[
                            const SizedBox(height: AppTheme.space4),
                            Wrap(
                              spacing: AppTheme.space4,
                              children: idea.tags.map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.space8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                ),
                                child: Text(
                                  tag,
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.primary,
                                  ),
                                ),
                              )).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Actions
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: AppTheme.textSecondaryColor(context)),
                      onSelected: (value) {
                        switch (value) {
                          case 'push':
                            _pushToTimeline(idea);
                            break;
                          case 'edit':
                            _showEditIdeaDialog(idea);
                            break;
                          case 'delete':
                            _deleteIdea(idea);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'push',
                          child: Row(
                            children: [
                              Icon(
                                Icons.timeline,
                                size: 18,
                                color: hasCompleteTimeBlock ? AppTheme.success : null,
                              ),
                              const SizedBox(width: 8),
                              const Text('Push to Timeline'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Push to Timeline button for items with complete timing
                if (hasCompleteTimeBlock && idea.status != TaskStatus.done) ...[
                  const SizedBox(height: AppTheme.space8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _pushToTimeline(idea),
                      icon: const Icon(Icons.timeline, size: 18),
                      label: const Text('Push to Timeline'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.success,
                        side: BorderSide(color: AppTheme.success),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return AppTheme.error;
      case TaskPriority.medium:
        return AppTheme.warning;
      case TaskPriority.low:
        return AppTheme.success;
    }
  }
  
  // Single robust space-color parser for this screen. Accepts named colors
  // ('blue', 'green', ...), '#RRGGBB', 'RRGGBB', and 'AARRGGBB' (including
  // the 'FFxxxxxx' format written on space creation). Falls back cleanly to
  // the app primary color.
  Color _getSpaceColor(String? colorValue) {
    if (colorValue == null || colorValue.trim().isEmpty) {
      return AppTheme.primary;
    }
    final value = colorValue.trim();

    const namedColors = <String, Color>{
      'blue': Colors.blue,
      'green': Colors.green,
      'purple': Colors.purple,
      'orange': Colors.orange,
      'pink': Colors.pink,
      'teal': Colors.teal,
      'red': Colors.red,
      'indigo': Colors.indigo,
    };
    final named = namedColors[value.toLowerCase()];
    if (named != null) return named;

    var hex = value.startsWith('#') ? value.substring(1) : value;
    if (hex.length == 6) hex = 'FF$hex'; // Assume fully opaque
    if (hex.length == 8) {
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed != null) return Color(parsed);
    }
    return AppTheme.primary;
  }
  
  void _showCreateSpaceDialog({String? parentSpaceId}) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(parentSpaceId != null ? 'Create Sub-space' : 'Create New Space'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Space Name',
                hintText: 'e.g., Work Ideas, Personal Goals',
              ),
              autofocus: true,
            ),
            const SizedBox(height: AppTheme.space16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Brief description of this space',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final newSpace = Space(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  description: descriptionController.text.isNotEmpty
                      ? descriptionController.text
                      : null,
                  color: 'FF${Colors.primaries[_spaces.length % Colors.primaries.length].toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
                  createdAt: DateTime.now(),
                  parentSpaceId: parentSpaceId,
                );

                // Close the dialog before any async work so its context is
                // never used after an await.
                Navigator.pop(dialogContext);

                await SpaceService.createSpace(newSpace);

                // Update parent space if it's a sub-space
                if (parentSpaceId != null) {
                  final parentSpace = _spaces
                      .where((s) => s.id == parentSpaceId)
                      .toList();
                  if (parentSpace.isNotEmpty) {
                    await SpaceService.updateSpace(parentSpace.first.copyWith(
                      subSpaceIds: [...parentSpace.first.subSpaceIds, newSpace.id],
                    ));
                  }
                }

                await _loadData();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
  
  void _showCreateSubSpaceDialog(String parentSpaceId) {
    _showCreateSpaceDialog(parentSpaceId: parentSpaceId);
  }
  
  Future<void> _quickAddIdea() async {
    if (_quickAddController.text.isNotEmpty && _selectedSpace != null) {
      await SpaceService.quickAddIdea(
        _quickAddController.text,
        spaceId: _selectedSpace!.id,
      );
      _quickAddController.clear();
      await _loadData();
    }
  }
  
  void _showIdeaDetails(EnhancedTask idea) {
    showDialog(
      context: context,
      builder: (context) => TaskDetailsDialog(
        enhancedTask: idea,
        cachedPrayerTimes: _cachedPrayerTimes,
        onEdit: () => _showEditIdeaDialog(idea),
        onDelete: () => _deleteIdea(idea),
      ),
    );
  }
  
  void _showEditIdeaDialog(EnhancedTask idea) async {
    final space = _spaces.firstWhere(
      (s) => s.id == (idea.spaceId ?? _selectedSpace?.id),
      orElse: () => _selectedSpace!,
    );
    
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditSpaceItemScreen(
          spaceId: idea.spaceId ?? _selectedSpace!.id,
          spaceName: space.name,
          spaceColor: _getSpaceColor(space.color),
          editingItem: idea,
        ),
      ),
    );
    
    if (result == true) {
      await _loadData();
    }
  }
  
  
  Future<void> _deleteIdea(EnhancedTask idea) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${idea.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await SpaceService.deleteEnhancedTask(idea.id);
      await _loadData();
    }
  }
  
  void _showDetailedAddDialog() async {
    if (_selectedSpace == null) return;
    
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditSpaceItemScreen(
          spaceId: _selectedSpace!.id,
          spaceName: _selectedSpace!.name,
          spaceColor: _getSpaceColor(_selectedSpace!.color),
        ),
      ),
    );
    
    if (result == true) {
      await _loadData();
    } else if (result is Map && result['item'] != null) {
      await _loadData();
      final item = result['item'] as EnhancedTask;
      if (result['pushToTimeline'] == true) {
        _pushToTimeline(item);
      } else if (result['offerPushToTimeline'] == true) {
        // The add screen has already popped; offer the push action from this
        // screen so the SnackBar action never touches a dead route.
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created "${item.title}"'),
            action: SnackBarAction(
              label: 'Push to Timeline',
              onPressed: () => _pushToTimeline(item),
            ),
          ),
        );
      }
    }
  }
  
  String _getScheduleDisplayText(EnhancedTask task) {
    if (task.scheduleType == ScheduleType.absolute) {
      if (task.absoluteTime != null && task.endTime != null) {
        final startTime = '${task.absoluteTime!.hour.toString().padLeft(2, '0')}:${task.absoluteTime!.minute.toString().padLeft(2, '0')}';
        final endTime = '${task.endTime!.hour.toString().padLeft(2, '0')}:${task.endTime!.minute.toString().padLeft(2, '0')}';
        return '$startTime - $endTime';
      } else if (task.absoluteTime != null) {
        return 'Starts at ${task.absoluteTime!.hour.toString().padLeft(2, '0')}:${task.absoluteTime!.minute.toString().padLeft(2, '0')}';
      }
    } else if (task.scheduleType == ScheduleType.prayerRelative && task.relatedPrayer != null) {
      // Calculate actual times for prayer-relative schedules
      return _calculatePrayerRelativeTimes(task);
    }
    
    return 'No schedule';
  }
  
  String _calculatePrayerRelativeTimes(EnhancedTask task) {
    // Use cached prayer times if available, otherwise show relative format
    if (_cachedPrayerTimes.isEmpty) {
      // Fallback to relative format if prayer times not loaded
      final prayer = task.relatedPrayer.toString().split('.').last;
      final beforeAfter = task.isBeforePrayer == true ? 'before' : 'after';
      final minutes = task.minutesOffset ?? 0;
      
      String text = '$minutes min $beforeAfter $prayer';
      
      if (task.endRelatedPrayer != null) {
        final endPrayer = task.endRelatedPrayer.toString().split('.').last;
        final endBeforeAfter = task.endIsBeforePrayer == true ? 'before' : 'after';
        final endMinutes = task.endMinutesOffset ?? 0;
        text += ' to $endMinutes min $endBeforeAfter $endPrayer';
      }
      
      return text;
    }
    
    // Calculate start time
    final startTime = _calculateSinglePrayerTime(
      task.relatedPrayer!,
      task.isBeforePrayer ?? false,
      task.minutesOffset ?? 0,
    );
    
    if (startTime == null) {
      return 'Invalid prayer time';
    }
    
    // Calculate end time if specified
    if (task.endRelatedPrayer != null) {
      final endTime = _calculateSinglePrayerTime(
        task.endRelatedPrayer!,
        task.endIsBeforePrayer ?? false,
        task.endMinutesOffset ?? 0,
      );
      
      if (endTime != null) {
        return '$startTime - $endTime';
      }
    }
    
    return 'Starts at $startTime';
  }
  
  String? _calculateSinglePrayerTime(PrayerName prayer, bool isBefore, int minutesOffset) {
    final prayerKey = prayer.toString().split('.').last;
    final prayerTimeStr = _cachedPrayerTimes[prayerKey.substring(0, 1).toUpperCase() + prayerKey.substring(1)];
    
    if (prayerTimeStr == null) return null;
    
    // Parse prayer time (format: "HH:mm")
    final parts = prayerTimeStr.split(':');
    if (parts.length != 2) return null;
    
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    
    if (hour == null || minute == null) return null;
    
    var prayerDateTime = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      hour,
      minute,
    );
    
    // Apply offset
    if (isBefore) {
      prayerDateTime = prayerDateTime.subtract(Duration(minutes: minutesOffset));
    } else {
      prayerDateTime = prayerDateTime.add(Duration(minutes: minutesOffset));
    }
    
    // Format as HH:MM
    return '${prayerDateTime.hour.toString().padLeft(2, '0')}:${prayerDateTime.minute.toString().padLeft(2, '0')}';
  }
  
  void _pushToTimeline(EnhancedTask idea) async {
    if (!idea.hasTimeBlock) {
      // Show timing dialog
      showDialog(
        context: context,
        builder: (dialogContext) => Dialog(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Set Time Block',
                      style: AppTheme.headlineSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      'This item needs both start and end times to be pushed to the timeline.',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondaryColor(dialogContext),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space24),
                    EnhancedItemForm(
                      spaceId: idea.spaceId ?? _selectedSpace!.id,
                      editingItem: idea,
                      onSubmit: (updatedItem) async {
                        // Pop the dialog before awaiting so its context is
                        // never used after the async gap.
                        Navigator.pop(dialogContext);
                        await SpaceService.updateEnhancedTask(updatedItem);
                        if (!mounted) return;

                        if (updatedItem.hasTimeBlock) {
                          // Now push to timeline
                          _pushToTimeline(updatedItem);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }
    
    // Create a task from the enhanced task
    final task = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: idea.title,
      description: idea.description,
      createdAt: DateTime.now(),
      scheduleType: idea.scheduleType,
      absoluteTime: idea.absoluteTime,
      endTime: idea.endTime,
      relatedPrayer: idea.relatedPrayer,
      isBeforePrayer: idea.isBeforePrayer,
      minutesOffset: idea.minutesOffset,
      endRelatedPrayer: idea.endRelatedPrayer,
      endIsBeforePrayer: idea.endIsBeforePrayer,
      endMinutesOffset: idea.endMinutesOffset,
      recurrence: idea.recurrence,
      priority: idea.priority,
    );
    
    await SpaceService.addTask(task);

    // Mark the source idea as scheduled (in progress) rather than done —
    // pushing to the timeline schedules the idea, it doesn't complete it.
    // Keep a reference to the created timeline task for traceability.
    final updatedIdea = idea.copyWith(
      status: TaskStatus.inProgress,
      customFields: {
        ...?idea.customFields,
        'timelineTaskId': task.id,
      },
    );

    await SpaceService.updateEnhancedTask(updatedIdea);
    await _loadData();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Scheduled "${idea.title}" on the timeline'),
        action: SnackBarAction(
          label: 'View Tasks',
          onPressed: () {
            // Navigate to tasks screen
            if (widget.onNavigateToTasks != null) {
              widget.onNavigateToTasks!();
            }
          },
        ),
      ),
    );
  }
  
  void _showSpaceOptionsMenu(Space space) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('Edit Space'),
              onTap: () {
                Navigator.pop(context);
                _showEditSpaceDialog(space);
              },
            ),
            ListTile(
              leading: Icon(Icons.create_new_folder),
              title: Text('Create Sub-space'),
              onTap: () {
                Navigator.pop(context);
                _showCreateSubSpaceDialog(space.id);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: AppTheme.error),
              title: Text('Delete Space', style: TextStyle(color: AppTheme.error)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteSpace(space);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _handleSpaceMenuAction(String action, Space space) {
    switch (action) {
      case 'edit':
        _showEditSpaceDialog(space);
        break;
      case 'create_subspace':
        _showCreateSubSpaceDialog(space.id);
        break;
      case 'delete':
        _confirmDeleteSpace(space);
        break;
    }
  }
  
  void _showEditSpaceDialog(Space space) {
    final nameController = TextEditingController(text: space.name);
    final descriptionController = TextEditingController(text: space.description);
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Space'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Space Name',
                hintText: 'e.g., Work Ideas, Personal Goals',
              ),
              autofocus: true,
            ),
            const SizedBox(height: AppTheme.space16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Brief description of this space',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final updatedSpace = space.copyWith(
                  name: nameController.text,
                  description: descriptionController.text.isNotEmpty
                      ? descriptionController.text
                      : null,
                );

                // Pop the dialog and capture the screen's messenger BEFORE
                // any async gap so no deactivated context is used later.
                Navigator.pop(dialogContext);
                final messenger = ScaffoldMessenger.of(context);

                await SpaceService.updateSpace(updatedSpace);
                await _loadData();

                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Updated "${updatedSpace.name}"'),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  void _confirmDeleteSpace(Space space) async {
    final subSpaces = _getSubSpaces(space.id);
    final itemCount = await SpaceService.getSpaceItemCount(space.id, includeSubSpaces: true);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Space'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${space.name}"?'),
            if (itemCount > 0) ...[
              const SizedBox(height: AppTheme.space12),
              Container(
                padding: const EdgeInsets.all(AppTheme.space12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Text(
                  'This space contains $itemCount item${itemCount > 1 ? 's' : ''}. '
                  'Items will be moved to unassigned.',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.warning,
                  ),
                ),
              ),
            ],
            if (subSpaces.isNotEmpty) ...[
              const SizedBox(height: AppTheme.space12),
              Text(
                'This space has ${subSpaces.length} sub-space${subSpaces.length > 1 ? 's' : ''}:',
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppTheme.space8),
              ...subSpaces.take(3).map((subSpace) => Padding(
                padding: const EdgeInsets.only(left: AppTheme.space16, bottom: AppTheme.space4),
                child: Row(
                  children: [
                    Icon(Icons.folder_outlined, size: 16, color: AppTheme.textSecondaryColor(dialogContext)),
                    const SizedBox(width: AppTheme.space8),
                    Text(
                      subSpace.name,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondaryColor(dialogContext),
                      ),
                    ),
                  ],
                ),
              )),
              if (subSpaces.length > 3)
                Padding(
                  padding: const EdgeInsets.only(left: AppTheme.space16),
                  child: Text(
                    '...and ${subSpaces.length - 3} more',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textTertiaryColor(dialogContext),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          if (subSpaces.isNotEmpty)
            TextButton(
              onPressed: () async {
                // Pop the dialog and capture the screen's messenger BEFORE
                // the async gap; the dialog context must not be used after.
                Navigator.pop(dialogContext);
                final messenger = ScaffoldMessenger.of(context);
                await SpaceService.deleteSpace(space.id, deleteSubSpaces: false);
                await _loadData();

                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Deleted "${space.name}" (sub-spaces preserved)'),
                  ),
                );
              },
              child: const Text('Delete Only This'),
            ),
          ElevatedButton(
            onPressed: () async {
              // Pop the dialog and capture the screen's messenger BEFORE
              // the async gap; the dialog context must not be used after.
              Navigator.pop(dialogContext);
              final messenger = ScaffoldMessenger.of(context);
              await SpaceService.deleteSpace(space.id, deleteSubSpaces: true);
              await _loadData();

              // If we deleted the selected space, reset selection
              if (mounted && _selectedSpace?.id == space.id) {
                setState(() {
                  _selectedSpace = null;
                  _showSpacesList = true;
                });
              }

              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    subSpaces.isEmpty
                        ? 'Deleted "${space.name}"'
                        : 'Deleted "${space.name}" and ${subSpaces.length} sub-space${subSpaces.length > 1 ? 's' : ''}'
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            child: Text(
              subSpaces.isEmpty ? 'Delete' : 'Delete All',
            ),
          ),
        ],
      ),
    );
  }
  
  List<Widget> _buildBreadcrumb(Space currentSpace) {
    final breadcrumb = <Widget>[];
    final spacePath = <Space>[];
    
    // Build path from current to root
    Space? space = currentSpace;
    while (space != null) {
      spacePath.insert(0, space);
      space = space.parentSpaceId != null
          ? _spaces.firstWhere(
              (s) => s.id == space!.parentSpaceId,
              orElse: () => space!,
            )
          : null;
      // Prevent infinite loop
      if (space != null && spacePath.contains(space)) break;
    }
    
    // Build breadcrumb widgets
    for (int i = 0; i < spacePath.length; i++) {
      final isLast = i == spacePath.length - 1;
      final space = spacePath[i];
      
      breadcrumb.add(
        InkWell(
          onTap: isLast ? null : () {
            setState(() {
              _selectedSpace = space;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space8,
              vertical: AppTheme.space4,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder,
                  size: 16,
                  color: isLast ? AppTheme.primary : AppTheme.textSecondaryColor(context),
                ),
                const SizedBox(width: AppTheme.space4),
                Text(
                  space.name,
                  style: AppTheme.bodySmall.copyWith(
                    color: isLast ? AppTheme.primary : AppTheme.textSecondaryColor(context),
                    fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      
      if (!isLast) {
        breadcrumb.add(
          Icon(
            Icons.chevron_right,
            size: 16,
            color: AppTheme.textTertiaryColor(context),
          ),
        );
      }
    }
    
    return breadcrumb;
  }
}