import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/activity.dart';
import '../models/space.dart';
import '../core/theme/app_theme.dart';

// TODO: Move these to a proper location
enum ActivityTimeFilter {
  all,       // Show all activities
  today,
  upcoming,
  past,
  thisWeek,
  custom,
}

class ActivityFilterOptions {
  final List<ActivityType> types;
  final List<ActivityTimeFilter> timeFilters;
  final List<String> spaceIds;
  final DateTime? specificDate;
  final DateTime? startDate;
  final DateTime? endDate;

  ActivityFilterOptions({
    this.types = const [],
    this.timeFilters = const [],
    this.spaceIds = const [],
    this.specificDate,
    this.startDate,
    this.endDate,
  });
}

class ActivityFilterDialog extends StatefulWidget {
  final ActivityFilterOptions initialOptions;
  final List<Space> spaces;
  final Function(ActivityFilterOptions) onApply;

  const ActivityFilterDialog({
    super.key,
    required this.initialOptions,
    required this.spaces,
    required this.onApply,
  });

  @override
  State<ActivityFilterDialog> createState() => _ActivityFilterDialogState();
}

class _ActivityFilterDialogState extends State<ActivityFilterDialog> {
  late List<ActivityType> _selectedTypes;
  late List<ActivityTimeFilter> _selectedTimeFilters;
  late List<String> _selectedSpaceIds;
  DateTime? _specificDate;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _selectedTypes = List.from(widget.initialOptions.types);
    _selectedTimeFilters = List.from(widget.initialOptions.timeFilters);
    _selectedSpaceIds = List.from(widget.initialOptions.spaceIds);
    _specificDate = widget.initialOptions.specificDate;
    _startDate = widget.initialOptions.startDate;
    _endDate = widget.initialOptions.endDate;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppTheme.space24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppTheme.borderLight),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter Activities',
                    style: AppTheme.headlineSmall.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.space24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time filters
                    _buildSectionTitle('Time'),
                    const SizedBox(height: AppTheme.space12),
                    Wrap(
                      spacing: AppTheme.space8,
                      runSpacing: AppTheme.space8,
                      children: ActivityTimeFilter.values.map((filter) {
                        return FilterChip(
                          label: Text(_getTimeFilterName(filter)),
                          selected: _selectedTimeFilters.contains(filter),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTimeFilters.clear();
                                _selectedTimeFilters.add(filter);
                                // Clear date selections when using preset filters
                                if (filter != ActivityTimeFilter.all) {
                                  _specificDate = null;
                                  _startDate = null;
                                  _endDate = null;
                                }
                              } else {
                                _selectedTimeFilters.remove(filter);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppTheme.space16),
                    
                    // Date range selector
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateField(
                            label: 'From',
                            date: _startDate,
                            onTap: () => _selectDateRange(true),
                          ),
                        ),
                        const SizedBox(width: AppTheme.space12),
                        Expanded(
                          child: _buildDateField(
                            label: 'To',
                            date: _endDate,
                            onTap: () => _selectDateRange(false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space24),

                    // Activity types
                    _buildSectionTitle('Activity Types'),
                    const SizedBox(height: AppTheme.space12),
                    Wrap(
                      spacing: AppTheme.space8,
                      runSpacing: AppTheme.space8,
                      children: ActivityType.values.map((type) {
                        return FilterChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                type.icon,
                                size: 18,
                                color: _selectedTypes.contains(type)
                                    ? Colors.white
                                    : type.defaultColor,
                              ),
                              const SizedBox(width: AppTheme.space4),
                              Text(type.displayName),
                            ],
                          ),
                          selected: _selectedTypes.contains(type),
                          selectedColor: type.defaultColor,
                          backgroundColor: type.defaultColor.withOpacity(0.1),
                          labelStyle: TextStyle(
                            color: _selectedTypes.contains(type)
                                ? Colors.white
                                : AppTheme.textPrimary,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTypes.add(type);
                              } else {
                                _selectedTypes.remove(type);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    
                    // Spaces
                    if (widget.spaces.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.space24),
                      _buildSectionTitle('Spaces'),
                      const SizedBox(height: AppTheme.space12),
                      Wrap(
                        spacing: AppTheme.space8,
                        runSpacing: AppTheme.space8,
                        children: widget.spaces.map((space) {
                          final isSelected = _selectedSpaceIds.contains(space.id);
                          return FilterChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (space.color != null)
                                  Container(
                                    width: 20,
                                    height: 20,
                                    margin: const EdgeInsets.only(right: AppTheme.space4),
                                    decoration: BoxDecoration(
                                      color: _parseColor(space.color!).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                Text(space.name),
                              ],
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedSpaceIds.add(space.id);
                                } else {
                                  _selectedSpaceIds.remove(space.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(AppTheme.space16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.borderLight),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedTypes.clear();
                        _selectedTimeFilters.clear();
                        _selectedSpaceIds.clear();
                        _specificDate = null;
                        _startDate = null;
                        _endDate = null;
                      });
                    },
                    child: const Text('Clear All'),
                  ),
                  const SizedBox(width: AppTheme.space16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppTheme.space8),
                  FilledButton(
                    onPressed: () {
                      final options = ActivityFilterOptions(
                        types: _selectedTypes,
                        timeFilters: _selectedTimeFilters,
                        spaceIds: _selectedSpaceIds,
                        specificDate: _specificDate,
                        startDate: _startDate,
                        endDate: _endDate,
                      );
                      widget.onApply(options);
                      Navigator.pop(context);
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTheme.titleMedium.copyWith(
        color: AppTheme.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space12),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.borderLight),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 20, color: AppTheme.textSecondary),
            const SizedBox(width: AppTheme.space8),
            Expanded(
              child: Text(
                date != null ? DateFormat('MMM d').format(date) : label,
                style: AppTheme.bodyMedium.copyWith(
                  color: date != null ? AppTheme.textPrimary : AppTheme.textTertiary,
                ),
              ),
            ),
            if (date != null)
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (label == 'From') {
                      _startDate = null;
                    } else {
                      _endDate = null;
                    }
                  });
                },
                child: Icon(Icons.clear, size: 18, color: AppTheme.textTertiary),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateRange(bool isStart) async {
    final initialDate = isStart ? _startDate : _endDate;
    final firstDate = isStart 
        ? DateTime.now().subtract(const Duration(days: 365))
        : (_startDate ?? DateTime.now().subtract(const Duration(days: 365)));
    
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
          if (_endDate != null && _endDate!.isBefore(date)) {
            _endDate = null;
          }
        } else {
          _endDate = date;
        }
        // Clear time filters when using date range
        _selectedTimeFilters.clear();
      });
    }
  }

  String _getTimeFilterName(ActivityTimeFilter filter) {
    switch (filter) {
      case ActivityTimeFilter.all:
        return 'All';
      case ActivityTimeFilter.today:
        return 'Today';
      case ActivityTimeFilter.thisWeek:
        return 'This Week';
      case ActivityTimeFilter.upcoming:
        return 'Upcoming';
      case ActivityTimeFilter.past:
        return 'Past';
      case ActivityTimeFilter.custom:
        return 'Custom';
    }
  }

  Color _parseColor(String colorString) {
    try {
      if (colorString.startsWith('#')) {
        return Color(int.parse(colorString.replaceFirst('#', '0xff')));
      } else if (colorString.startsWith('0x') || colorString.startsWith('0X')) {
        return Color(int.parse(colorString));
      } else if (colorString.length == 6) {
        return Color(int.parse('0xff$colorString', radix: 16));
      } else if (colorString.length == 8 && colorString.toUpperCase().startsWith('FF')) {
        return Color(int.parse('0x$colorString', radix: 16));
      } else {
        return Color(int.parse('0xff$colorString', radix: 16));
      }
    } catch (e) {
      return AppTheme.primary;
    }
  }
}