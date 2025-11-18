import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/space.dart';
import '../core/theme/app_theme.dart';
import '../core/services/task_filter_service.dart';

class TaskFilterDialog extends StatefulWidget {
  final TaskFilterOptions initialFilters;
  final List<Space> availableSpaces;
  final SortOption? currentSort;

  const TaskFilterDialog({
    super.key,
    required this.initialFilters,
    required this.availableSpaces,
    this.currentSort,
  });

  @override
  State<TaskFilterDialog> createState() => _TaskFilterDialogState();
}

class _TaskFilterDialogState extends State<TaskFilterDialog> {
  late TaskFilterOptions _filters;
  DateFilterType _dateFilterType = DateFilterType.none;
  SortOption? _selectedSort;
  final TextEditingController _presetNameController = TextEditingController();
  Map<String, TaskFilterOptions> _savedPresets = {};
  bool _isLoadingPresets = true;

  @override
  void initState() {
    super.initState();
    _filters = TaskFilterOptions(
      specificDate: widget.initialFilters.specificDate,
      startDate: widget.initialFilters.startDate,
      endDate: widget.initialFilters.endDate,
      statuses: Set.from(widget.initialFilters.statuses),
      spaceIds: Set.from(widget.initialFilters.spaceIds),
      priorities: Set.from(widget.initialFilters.priorities),
      itemTypes: Set.from(widget.initialFilters.itemTypes),
      searchQuery: widget.initialFilters.searchQuery,
      searchInTags: widget.initialFilters.searchInTags,
    );

    _selectedSort = widget.currentSort;

    // Set initial date filter type
    if (_filters.specificDate != null) {
      _dateFilterType = DateFilterType.specific;
    } else if (_filters.startDate != null && _filters.endDate != null) {
      _dateFilterType = DateFilterType.range;
    }

    _loadPresets();
  }

  @override
  void dispose() {
    _presetNameController.dispose();
    super.dispose();
  }

  Future<void> _loadPresets() async {
    final presets = await TaskFilterService.loadFilterPresets();
    if (mounted) {
      setState(() {
        _savedPresets = presets;
        _isLoadingPresets = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: isMobile ? 24 : 40,
      ),
      child: Container(
        width: isMobile ? double.infinity : 600,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: isMobile ? screenWidth - 32 : 600,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    TabBar(
                      tabs: const [
                        Tab(text: 'Filters'),
                        Tab(text: 'Sort'),
                        Tab(text: 'Presets'),
                      ],
                      labelColor: AppTheme.primary,
                      unselectedLabelColor: AppTheme.textSecondary,
                    ),
                    Flexible(
                      child: TabBarView(
                        children: [
                          _buildFiltersTab(),
                          _buildSortTab(),
                          _buildPresetsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderLight),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Filter & Sort Tasks',
            style: AppTheme.headlineSmall,
          ),
          const Spacer(),
          if (_filters.hasActiveFilters)
            TextButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear All'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.error,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFiltersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateSection(),
          const SizedBox(height: AppTheme.space24),
          _buildStatusSection(),
          const SizedBox(height: AppTheme.space24),
          _buildSpaceSection(),
          const SizedBox(height: AppTheme.space24),
          _buildPrioritySection(),
          const SizedBox(height: AppTheme.space24),
          _buildItemTypeSection(),
        ],
      ),
    );
  }

  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Date Filter',
              style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            // Quick presets dropdown
            PopupMenuButton<DatePreset>(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space12,
                  vertical: AppTheme.space6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primary),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.schedule, size: 16, color: AppTheme.primary),
                    SizedBox(width: AppTheme.space4),
                    Text('Quick Presets', style: TextStyle(color: AppTheme.primary)),
                    Icon(Icons.arrow_drop_down, size: 16, color: AppTheme.primary),
                  ],
                ),
              ),
              itemBuilder: (context) => TaskFilterService.getDatePresets()
                  .map((preset) => PopupMenuItem(
                        value: preset,
                        child: Text(preset.name),
                      ))
                  .toList(),
              onSelected: (preset) {
                setState(() {
                  _dateFilterType = DateFilterType.range;
                  _filters.startDate = preset.startDate;
                  _filters.endDate = preset.endDate;
                  _filters.specificDate = null;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space12),
        Wrap(
          spacing: AppTheme.space8,
          runSpacing: AppTheme.space8,
          children: [
            _buildDateFilterChip(DateFilterType.specific, 'Specific Date'),
            _buildDateFilterChip(DateFilterType.range, 'Date Range'),
          ],
        ),
        if (_dateFilterType != DateFilterType.none) ...[
          const SizedBox(height: AppTheme.space16),
          _buildDatePicker(),
        ],
      ],
    );
  }

  Widget _buildDateFilterChip(DateFilterType type, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _dateFilterType == type,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _dateFilterType = type;
          } else {
            _dateFilterType = DateFilterType.none;
            _filters.clearDateFilter();
          }
        });
      },
    );
  }

  Widget _buildDatePicker() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    if (_dateFilterType == DateFilterType.specific) {
      return InkWell(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _filters.specificDate ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          );
          if (date != null) {
            setState(() {
              _filters.specificDate = date;
              _filters.startDate = null;
              _filters.endDate = null;
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.all(AppTheme.space12),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.borderLight),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 20),
              const SizedBox(width: AppTheme.space8),
              Text(
                _filters.specificDate != null
                    ? DateFormat('MMM d, yyyy').format(_filters.specificDate!)
                    : 'Select Date',
                style: AppTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    } else if (_dateFilterType == DateFilterType.range) {
      final dateRangeWidgets = [
        Expanded(
          flex: isMobile ? 0 : 1,
          child: InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _filters.startDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (date != null) {
                setState(() {
                  _filters.startDate = date;
                  _filters.specificDate = null;
                  // Validate end date
                  if (_filters.endDate != null && _filters.endDate!.isBefore(date)) {
                    _filters.endDate = date;
                  }
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.all(AppTheme.space12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _filters.startDate != null && _filters.endDate != null &&
                         _filters.startDate!.isAfter(_filters.endDate!)
                      ? AppTheme.error
                      : AppTheme.borderLight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: Text(
                      _filters.startDate != null
                          ? DateFormat('MMM d, yyyy').format(_filters.startDate!)
                          : 'Start Date',
                      style: AppTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isMobile)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.space8),
            child: Icon(Icons.arrow_forward, size: 20),
          ),
        if (isMobile) const SizedBox(height: AppTheme.space12),
        Expanded(
          flex: isMobile ? 0 : 1,
          child: InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _filters.endDate ?? _filters.startDate ?? DateTime.now(),
                firstDate: _filters.startDate ?? DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (date != null) {
                setState(() {
                  _filters.endDate = date;
                  _filters.specificDate = null;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.all(AppTheme.space12),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderLight),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: Text(
                      _filters.endDate != null
                          ? DateFormat('MMM d, yyyy').format(_filters.endDate!)
                          : 'End Date',
                      style: AppTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
      
      return isMobile 
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: dateRangeWidgets,
            )
          : Row(children: dateRangeWidgets);
    }
    return const SizedBox();
  }

  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Task Status',
              style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: AppTheme.space8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space8,
                vertical: AppTheme.space4,
              ),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Text(
                '${_filters.statuses.length} selected',
                style: AppTheme.labelSmall.copyWith(color: AppTheme.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space12),
        Wrap(
          spacing: AppTheme.space8,
          runSpacing: AppTheme.space8,
          children: TaskStatus.values.map((status) {
            final isSelected = _filters.statuses.contains(status);
            return FilterChip(
              label: Text(_getStatusLabel(status)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _filters.statuses.add(status);
                  } else {
                    _filters.statuses.remove(status);
                  }
                });
              },
              selectedColor: _getStatusColor(status).withOpacity(0.2),
              checkmarkColor: _getStatusColor(status),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSpaceSection() {
    if (widget.availableSpaces.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Spaces',
              style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: AppTheme.space8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space8,
                vertical: AppTheme.space4,
              ),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Text(
                '${_filters.spaceIds.length} selected',
                style: AppTheme.labelSmall.copyWith(color: AppTheme.secondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space12),
        Wrap(
          spacing: AppTheme.space8,
          runSpacing: AppTheme.space8,
          children: widget.availableSpaces.map((space) {
            final isSelected = _filters.spaceIds.contains(space.id);
            return FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder,
                    size: 16,
                    color: isSelected ? _getSpaceColor(space.color) : null,
                  ),
                  const SizedBox(width: AppTheme.space4),
                  Text(space.name),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _filters.spaceIds.add(space.id);
                  } else {
                    _filters.spaceIds.remove(space.id);
                  }
                });
              },
              selectedColor: _getSpaceColor(space.color).withOpacity(0.2),
              checkmarkColor: _getSpaceColor(space.color),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPrioritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Priority',
          style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppTheme.space12),
        Wrap(
          spacing: AppTheme.space8,
          runSpacing: AppTheme.space8,
          children: TaskPriority.values.map((priority) {
            final isSelected = _filters.priorities.contains(priority);
            return FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getPriorityIcon(priority),
                    size: 16,
                    color: isSelected ? _getPriorityColor(priority) : null,
                  ),
                  const SizedBox(width: AppTheme.space4),
                  Text(priority.name.toUpperCase()),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _filters.priorities.add(priority);
                  } else {
                    _filters.priorities.remove(priority);
                  }
                });
              },
              selectedColor: _getPriorityColor(priority).withOpacity(0.2),
              checkmarkColor: _getPriorityColor(priority),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildItemTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Item Type',
          style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppTheme.space12),
        Wrap(
          spacing: AppTheme.space8,
          runSpacing: AppTheme.space8,
          children: ItemType.values.map((type) {
            final isSelected = _filters.itemTypes.contains(type);
            return FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getItemTypeIcon(type),
                    size: 16,
                    color: isSelected ? _getItemTypeColor(type) : null,
                  ),
                  const SizedBox(width: AppTheme.space4),
                  Text(type.name.substring(0, 1).toUpperCase() + type.name.substring(1)),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _filters.itemTypes.add(type);
                  } else {
                    _filters.itemTypes.remove(type);
                  }
                });
              },
              selectedColor: _getItemTypeColor(type).withOpacity(0.2),
              checkmarkColor: _getItemTypeColor(type),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSortTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sort By',
            style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTheme.space16),
          ...TaskFilterService.availableSortOptions.map((option) {
            final isSelected = _selectedSort?.field == option.field &&
                               _selectedSort?.ascending == option.ascending;
            return RadioListTile<SortOption>(
              title: Text(option.label),
              value: option,
              groupValue: _selectedSort,
              selected: isSelected,
              activeColor: AppTheme.primary,
              onChanged: (value) {
                setState(() {
                  _selectedSort = value;
                });
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPresetsTab() {
    if (_isLoadingPresets) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Save current as preset
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Save Current Filters',
                    style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppTheme.space12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _presetNameController,
                          decoration: const InputDecoration(
                            hintText: 'Preset name',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.space12),
                      FilledButton.icon(
                        onPressed: _filters.hasActiveFilters && _presetNameController.text.isNotEmpty
                            ? () async {
                                await TaskFilterService.saveFilterPreset(
                                  _presetNameController.text,
                                  _filters,
                                );
                                _presetNameController.clear();
                                await _loadPresets();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Preset saved'),
                                      backgroundColor: AppTheme.success,
                                    ),
                                  );
                                }
                              }
                            : null,
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space20),
          
          // Saved presets
          Text(
            'Saved Presets',
            style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTheme.space12),
          
          if (_savedPresets.isEmpty)
            Center(
              child: Text(
                'No saved presets',
                style: AppTheme.bodyLarge.copyWith(color: AppTheme.textSecondary),
              ),
            )
          else
            ..._savedPresets.entries.map((entry) {
              return Card(
                margin: const EdgeInsets.only(bottom: AppTheme.space8),
                child: ListTile(
                  title: Text(entry.key),
                  subtitle: Text(_getPresetSummary(entry.value)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline),
                        color: AppTheme.success,
                        onPressed: () {
                          setState(() {
                            _filters = TaskFilterOptions(
                              specificDate: entry.value.specificDate,
                              startDate: entry.value.startDate,
                              endDate: entry.value.endDate,
                              statuses: Set.from(entry.value.statuses),
                              spaceIds: Set.from(entry.value.spaceIds),
                              priorities: Set.from(entry.value.priorities),
                              itemTypes: Set.from(entry.value.itemTypes),
                              searchQuery: entry.value.searchQuery,
                              searchInTags: entry.value.searchInTags,
                            );
                            
                            // Update date filter type
                            if (_filters.specificDate != null) {
                              _dateFilterType = DateFilterType.specific;
                            } else if (_filters.startDate != null && _filters.endDate != null) {
                              _dateFilterType = DateFilterType.range;
                            } else {
                              _dateFilterType = DateFilterType.none;
                            }
                          });
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Applied preset: ${entry.key}'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: AppTheme.error,
                        onPressed: () async {
                          await TaskFilterService.deleteFilterPreset(entry.key);
                          await _loadPresets();
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  String _getPresetSummary(TaskFilterOptions preset) {
    final parts = <String>[];
    
    if (preset.specificDate != null) {
      parts.add('Date: ${DateFormat('MMM d').format(preset.specificDate!)}');
    } else if (preset.startDate != null && preset.endDate != null) {
      parts.add('${DateFormat('MMM d').format(preset.startDate!)} - ${DateFormat('MMM d').format(preset.endDate!)}');
    }
    
    if (preset.statuses.isNotEmpty) {
      parts.add('${preset.statuses.length} status');
    }
    
    if (preset.priorities.isNotEmpty) {
      parts.add('${preset.priorities.length} priority');
    }
    
    if (preset.spaceIds.isNotEmpty) {
      parts.add('${preset.spaceIds.length} spaces');
    }
    
    return parts.isEmpty ? 'No filters' : parts.join(', ');
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.borderLight),
        ),
      ),
      child: Row(
        children: [
          // Export button
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export filtered results',
            onPressed: () {
              Navigator.of(context).pop({
                'filters': _filters,
                'sort': _selectedSort,
                'export': true,
              });
            },
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: AppTheme.space12),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop({
              'filters': _filters,
              'sort': _selectedSort,
            }),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _filters = TaskFilterOptions();
      _dateFilterType = DateFilterType.none;
      _selectedSort = null;
    });
  }

  String _getStatusLabel(TaskStatus status) {
    switch (status) {
      case TaskStatus.all:
        return 'All';
      case TaskStatus.today:
        return 'Today';
      case TaskStatus.upcoming:
        return 'Upcoming';
      case TaskStatus.completed:
        return 'Completed';
      case TaskStatus.missed:
        return 'Missed';
      case TaskStatus.overdue:
        return 'Overdue';
      case TaskStatus.old:
        return 'Old';
    }
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.all:
        return AppTheme.primary;
      case TaskStatus.today:
        return AppTheme.info;
      case TaskStatus.upcoming:
        return AppTheme.secondary;
      case TaskStatus.completed:
        return AppTheme.success;
      case TaskStatus.missed:
        return AppTheme.error;
      case TaskStatus.overdue:
        return AppTheme.warning;
      case TaskStatus.old:
        return AppTheme.textSecondary;
    }
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

  IconData _getPriorityIcon(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Icons.priority_high_rounded;
      case TaskPriority.medium:
        return Icons.remove_rounded;
      case TaskPriority.low:
        return Icons.arrow_downward_rounded;
    }
  }

  IconData _getItemTypeIcon(ItemType type) {
    switch (type) {
      case ItemType.task:
        return Icons.task_alt;
      case ItemType.activity:
        return Icons.directions_run;
      case ItemType.event:
        return Icons.event;
      case ItemType.session:
        return Icons.computer;
      case ItemType.routine:
        return Icons.repeat;
      case ItemType.appointment:
        return Icons.people;
      case ItemType.reminder:
        return Icons.notifications;
    }
  }

  Color _getItemTypeColor(ItemType type) {
    switch (type) {
      case ItemType.task:
        return AppTheme.primary;
      case ItemType.activity:
        return Colors.orange;
      case ItemType.event:
        return Colors.purple;
      case ItemType.session:
        return Colors.blue;
      case ItemType.routine:
        return Colors.green;
      case ItemType.appointment:
        return Colors.red;
      case ItemType.reminder:
        return Colors.amber;
    }
  }

  Color _getSpaceColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) {
      return AppTheme.primary;
    }
    try {
      return Color(int.parse(colorHex, radix: 16));
    } catch (e) {
      return AppTheme.primary;
    }
  }
}

enum DateFilterType {
  none,
  specific,
  range,
}