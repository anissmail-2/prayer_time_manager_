import 'task.dart';

// Enhanced task model that extends the base Task
class EnhancedTask extends Task {
  final String? spaceId; // Optional space reference
  final String? parentTaskId; // For subtasks
  final List<String> subtaskIds; // Child tasks
  final List<String> tags; // Flexible categorization
  final TaskStatus status; // More granular than just completed
  final int? actualMinutes; // Time tracking
  final String? notes; // Additional notes
  final List<String> attachments; // File references
  final Map<String, dynamic>? customFields; // Flexible data
  
  EnhancedTask({
    // Base Task fields
    required super.id,
    required super.title,
    super.description,
    required super.createdAt,
    super.isCompleted,
    super.priority,
    super.itemType,
    required super.scheduleType,
    super.absoluteTime,
    super.endTime,
    super.relatedPrayer,
    super.isBeforePrayer,
    super.minutesOffset,
    super.endRelatedPrayer,
    super.endIsBeforePrayer,
    super.endMinutesOffset,
    required super.recurrence,
    super.weeklyDays,
    super.startDate,
    super.endDate,
    super.weeklyInterval,
    super.monthlyDates,
    super.monthlyPattern,
    super.completedDates,
    super.estimatedMinutes,
    
    // Enhanced fields
    this.spaceId,
    this.parentTaskId,
    List<String>? subtaskIds,
    List<String>? tags,
    this.status = TaskStatus.todo,
    this.actualMinutes,
    this.notes,
    List<String>? attachments,
    this.customFields,
  }) : subtaskIds = subtaskIds ?? [],
       tags = tags ?? [],
       attachments = attachments ?? [];
  
  // Check if this is a subtask
  bool get isSubtask => parentTaskId != null;
  
  // Check if this has subtasks
  bool get hasSubtasks => subtaskIds.isNotEmpty;
  
  // Check if task is scheduled
  bool get isScheduled => 
      scheduleType == ScheduleType.absolute && absoluteTime != null ||
      scheduleType == ScheduleType.prayerRelative && relatedPrayer != null;
  
  // Check if task has complete time block
  bool get hasTimeBlock => 
      (scheduleType == ScheduleType.absolute && absoluteTime != null && endTime != null) ||
      (scheduleType == ScheduleType.prayerRelative && relatedPrayer != null);
  
  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    return {
      ...baseJson,
      'spaceId': spaceId,
      'parentTaskId': parentTaskId,
      'subtaskIds': subtaskIds,
      'tags': tags,
      'status': status.index,
      'actualMinutes': actualMinutes,
      'notes': notes,
      'attachments': attachments,
      'customFields': customFields,
    };
  }
  
  factory EnhancedTask.fromJson(Map<String, dynamic> json) {
    // First create base task
    final baseTask = Task.fromJson(json);
    
    return EnhancedTask(
      // Base fields
      id: baseTask.id,
      title: baseTask.title,
      description: baseTask.description,
      createdAt: baseTask.createdAt,
      isCompleted: baseTask.isCompleted,
      priority: baseTask.priority,
      itemType: baseTask.itemType,
      scheduleType: baseTask.scheduleType,
      absoluteTime: baseTask.absoluteTime,
      endTime: baseTask.endTime,
      relatedPrayer: baseTask.relatedPrayer,
      isBeforePrayer: baseTask.isBeforePrayer,
      minutesOffset: baseTask.minutesOffset,
      endRelatedPrayer: baseTask.endRelatedPrayer,
      endIsBeforePrayer: baseTask.endIsBeforePrayer,
      endMinutesOffset: baseTask.endMinutesOffset,
      recurrence: baseTask.recurrence,
      weeklyDays: baseTask.weeklyDays,
      startDate: baseTask.startDate,
      endDate: baseTask.endDate,
      weeklyInterval: baseTask.weeklyInterval,
      monthlyDates: baseTask.monthlyDates,
      monthlyPattern: baseTask.monthlyPattern,
      completedDates: baseTask.completedDates,
      estimatedMinutes: baseTask.estimatedMinutes,
      
      // Enhanced fields
      spaceId: json['spaceId'] ?? json['projectId'],
      parentTaskId: json['parentTaskId'],
      subtaskIds: List<String>.from(json['subtaskIds'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      status: TaskStatus.values[json['status'] ?? 0],
      actualMinutes: json['actualMinutes'],
      notes: json['notes'],
      attachments: List<String>.from(json['attachments'] ?? []),
      customFields: json['customFields'],
    );
  }
  
  // Create unscheduled task (for backlog/inbox)
  factory EnhancedTask.unscheduled({
    required String id,
    required String title,
    String? description,
    String? spaceId,
    TaskPriority priority = TaskPriority.medium,
    List<String>? tags,
    String? notes,
  }) {
    return EnhancedTask(
      id: id,
      title: title,
      description: description,
      createdAt: DateTime.now(),
      scheduleType: ScheduleType.absolute, // But no absoluteTime set
      recurrence: TaskRecurrence.once,
      priority: priority,
      spaceId: spaceId,
      tags: tags,
      notes: notes,
      status: TaskStatus.todo,
    );
  }
  
  // Convert to scheduled task
  EnhancedTask schedule({
    DateTime? absoluteTime,
    DateTime? endTime,
    PrayerName? relatedPrayer,
    bool? isBeforePrayer,
    int? minutesOffset,
    PrayerName? endRelatedPrayer,
    bool? endIsBeforePrayer,
    int? endMinutesOffset,
    TaskRecurrence? recurrence,
  }) {
    return EnhancedTask(
      // Copy all existing fields
      id: id,
      title: title,
      description: description,
      createdAt: createdAt,
      isCompleted: isCompleted,
      priority: priority,
      spaceId: spaceId,
      parentTaskId: parentTaskId,
      subtaskIds: subtaskIds,
      tags: tags,
      status: status,
      estimatedMinutes: estimatedMinutes,
      actualMinutes: actualMinutes,
      notes: notes,
      attachments: attachments,
      customFields: customFields,
      completedDates: completedDates,
      weeklyDays: weeklyDays,
      endDate: endDate,
      
      // Update scheduling
      scheduleType: relatedPrayer != null ? ScheduleType.prayerRelative : ScheduleType.absolute,
      absoluteTime: absoluteTime ?? this.absoluteTime,
      endTime: endTime ?? this.endTime,
      relatedPrayer: relatedPrayer ?? this.relatedPrayer,
      isBeforePrayer: isBeforePrayer ?? this.isBeforePrayer,
      minutesOffset: minutesOffset ?? this.minutesOffset,
      endRelatedPrayer: endRelatedPrayer ?? this.endRelatedPrayer,
      endIsBeforePrayer: endIsBeforePrayer ?? this.endIsBeforePrayer,
      endMinutesOffset: endMinutesOffset ?? this.endMinutesOffset,
      recurrence: recurrence ?? this.recurrence,
    );
  }
  
  // Copy with method for updating specific fields
  @override
  EnhancedTask copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isCompleted,
    TaskPriority? priority,
    ItemType? itemType,
    ScheduleType? scheduleType,
    DateTime? absoluteTime,
    DateTime? endTime,
    PrayerName? relatedPrayer,
    bool? isBeforePrayer,
    int? minutesOffset,
    PrayerName? endRelatedPrayer,
    bool? endIsBeforePrayer,
    int? endMinutesOffset,
    TaskRecurrence? recurrence,
    List<int>? weeklyDays,
    DateTime? startDate,
    DateTime? endDate,
    int? weeklyInterval,
    List<int>? monthlyDates,
    String? monthlyPattern,
    List<DateTime>? completedDates,
    String? spaceId,
    String? parentTaskId,
    List<String>? subtaskIds,
    List<String>? tags,
    TaskStatus? status,
    int? estimatedMinutes,
    int? actualMinutes,
    String? notes,
    List<String>? attachments,
    Map<String, dynamic>? customFields,
  }) {
    return EnhancedTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      itemType: itemType ?? this.itemType,
      scheduleType: scheduleType ?? this.scheduleType,
      absoluteTime: absoluteTime ?? this.absoluteTime,
      endTime: endTime ?? this.endTime,
      relatedPrayer: relatedPrayer ?? this.relatedPrayer,
      isBeforePrayer: isBeforePrayer ?? this.isBeforePrayer,
      minutesOffset: minutesOffset ?? this.minutesOffset,
      endRelatedPrayer: endRelatedPrayer ?? this.endRelatedPrayer,
      endIsBeforePrayer: endIsBeforePrayer ?? this.endIsBeforePrayer,
      endMinutesOffset: endMinutesOffset ?? this.endMinutesOffset,
      recurrence: recurrence ?? this.recurrence,
      weeklyDays: weeklyDays ?? this.weeklyDays,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      weeklyInterval: weeklyInterval ?? this.weeklyInterval,
      monthlyDates: monthlyDates ?? this.monthlyDates,
      monthlyPattern: monthlyPattern ?? this.monthlyPattern,
      completedDates: completedDates ?? this.completedDates,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      spaceId: spaceId ?? this.spaceId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      subtaskIds: subtaskIds ?? this.subtaskIds,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      notes: notes ?? this.notes,
      attachments: attachments ?? this.attachments,
      customFields: customFields ?? this.customFields,
    );
  }
}

enum TaskStatus {
  todo,       // Not started
  inProgress, // Being worked on
  blocked,    // Waiting for something
  review,     // Needs review
  done,       // Completed
  cancelled,  // Won't do
}