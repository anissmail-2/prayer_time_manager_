import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/space.dart';
import '../../models/enhanced_task.dart';
import '../../models/task.dart';
import 'todo_service.dart';
import 'auth_service.dart';
import 'firestore_space_service.dart';

class SpaceService {
  static const String _spacesKey = 'spaces';
  static const String _enhancedTasksKey = 'enhanced_tasks';
  
  // Spaces
  static Future<List<Space>> getAllSpaces() async {
    // Use Firestore when logged in
    if (AuthService.isLoggedIn) {
      try {
        return await FirestoreSpaceService.getAllSpaces();
      } catch (e) {
        print('Error getting spaces from Firestore: $e');
        return [];
      }
    }
    
    // Only use local storage when not logged in
    final prefs = await SharedPreferences.getInstance();
    final spacesJson = prefs.getString(_spacesKey);
    
    if (spacesJson != null) {
      final List<dynamic> spacesList = jsonDecode(spacesJson);
      return spacesList.map((json) => Space.fromJson(json)).toList();
    }
    
    // Migration from old projects key
    final projectsJson = prefs.getString('projects');
    if (projectsJson != null) {
      final List<dynamic> projectsList = jsonDecode(projectsJson);
      final spaces = projectsList.map((json) => Space.fromJson(json)).toList();
      await _saveSpaces(spaces);
      await prefs.remove('projects'); // Clean up old key
      return spaces;
    }
    
    return [];
  }
  
  static Future<Space?> getSpace(String id) async {
    final spaces = await getAllSpaces();
    try {
      return spaces.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }
  
  static Future<void> createSpace(Space space) async {
    if (AuthService.isLoggedIn) {
      // Use Firestore directly when logged in
      await FirestoreSpaceService.createSpace(space);
      return;
    }
    
    // Only use local storage when not logged in
    final spaces = await getAllSpaces();
    spaces.add(space);
    await _saveSpaces(spaces);
  }
  
  static Future<void> updateSpace(Space space) async {
    if (AuthService.isLoggedIn) {
      // Use Firestore directly when logged in
      return FirestoreSpaceService.updateSpace(space);
    }
    
    // Only use local storage when not logged in
    final spaces = await getAllSpaces();
    final index = spaces.indexWhere((s) => s.id == space.id);
    if (index != -1) {
      spaces[index] = space;
      await _saveSpaces(spaces);
    }
  }
  
  static Future<void> deleteSpace(String id, {bool deleteSubSpaces = true, String? reassignToSpaceId}) async {
    if (AuthService.isLoggedIn) {
      // Use Firestore directly when logged in
      return FirestoreSpaceService.deleteSpace(id);
    }
    
    // Only use local storage when not logged in
    final spaces = await getAllSpaces();
    final spaceToDelete = spaces.firstWhere((s) => s.id == id);
    
    // Handle sub-spaces
    if (spaceToDelete.subSpaceIds.isNotEmpty) {
      if (deleteSubSpaces) {
        // Recursively delete all sub-spaces
        for (final subSpaceId in spaceToDelete.subSpaceIds) {
          await deleteSpace(subSpaceId, deleteSubSpaces: true);
        }
      } else {
        // Make sub-spaces root level or reassign to another parent
        for (final subSpaceId in spaceToDelete.subSpaceIds) {
          final subSpace = await getSpace(subSpaceId);
          if (subSpace != null) {
            await updateSpace(subSpace.copyWith(
              parentSpaceId: reassignToSpaceId,
            ));
            
            // If reassigning to another parent, update that parent's subSpaceIds
            if (reassignToSpaceId != null) {
              final newParent = await getSpace(reassignToSpaceId);
              if (newParent != null && !newParent.subSpaceIds.contains(subSpaceId)) {
                await updateSpace(newParent.copyWith(
                  subSpaceIds: [...newParent.subSpaceIds, subSpaceId],
                ));
              }
            }
          }
        }
      }
    }
    
    // Remove space from parent's sub-space list if it has a parent
    if (spaceToDelete.parentSpaceId != null) {
      final parentSpace = await getSpace(spaceToDelete.parentSpaceId!);
      if (parentSpace != null) {
        final updatedSubSpaceIds = List<String>.from(parentSpace.subSpaceIds)
          ..remove(id);
        await updateSpace(parentSpace.copyWith(subSpaceIds: updatedSubSpaceIds));
      }
    }
    
    // Remove the space itself
    spaces.removeWhere((s) => s.id == id);
    await _saveSpaces(spaces);
    
    // Handle tasks in the deleted space
    final tasks = await getAllEnhancedTasks();
    for (final task in tasks.where((t) => t.spaceId == id)) {
      if (reassignToSpaceId != null) {
        // Reassign tasks to another space
        await updateEnhancedTask(task.copyWith(spaceId: reassignToSpaceId));
      } else {
        // Remove space reference from tasks
        await updateEnhancedTask(task.copyWith(spaceId: null));
      }
    }
  }
  
  static Future<void> _saveSpaces(List<Space> spaces) async {
    final prefs = await SharedPreferences.getInstance();
    final spacesJson = jsonEncode(spaces.map((s) => s.toJson()).toList());
    await prefs.setString(_spacesKey, spacesJson);
  }
  
  // Enhanced Tasks
  static Future<List<EnhancedTask>> getAllEnhancedTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getString(_enhancedTasksKey);
    
    if (tasksJson != null) {
      final List<dynamic> tasksList = jsonDecode(tasksJson);
      return tasksList.map((json) => EnhancedTask.fromJson(json)).toList();
    }
    
    return [];
  }
  
  static Future<List<EnhancedTask>> getSpaceTasks(String spaceId) async {
    final tasks = await getAllEnhancedTasks();
    return tasks.where((t) => t.spaceId == spaceId).toList();
  }
  
  static Future<List<EnhancedTask>> getUnscheduledTasks() async {
    final tasks = await getAllEnhancedTasks();
    return tasks.where((t) => !t.isScheduled && !t.isCompleted).toList();
  }
  
  static Future<List<EnhancedTask>> getSubtasks(String parentTaskId) async {
    final tasks = await getAllEnhancedTasks();
    return tasks.where((t) => t.parentTaskId == parentTaskId).toList();
  }
  
  static Future<void> createEnhancedTask(EnhancedTask task) async {
    final tasks = await getAllEnhancedTasks();
    tasks.add(task);
    await _saveEnhancedTasks(tasks);
    
    // If task belongs to a space, add to space's item list
    if (task.spaceId != null) {
      final space = await getSpace(task.spaceId!);
      if (space != null && !space.itemIds.contains(task.id)) {
        final updatedSpace = space.copyWith(
          itemIds: [...space.itemIds, task.id],
        );
        await updateSpace(updatedSpace);
      }
    }
    
    // If task is a subtask, add to parent's subtask list
    if (task.parentTaskId != null) {
      final parentTask = await getEnhancedTask(task.parentTaskId!);
      if (parentTask != null && !parentTask.subtaskIds.contains(task.id)) {
        await updateEnhancedTask(EnhancedTask(
          id: parentTask.id,
          title: parentTask.title,
          description: parentTask.description,
          createdAt: parentTask.createdAt,
          isCompleted: parentTask.isCompleted,
          priority: parentTask.priority,
          scheduleType: parentTask.scheduleType,
          absoluteTime: parentTask.absoluteTime,
          relatedPrayer: parentTask.relatedPrayer,
          isBeforePrayer: parentTask.isBeforePrayer,
          minutesOffset: parentTask.minutesOffset,
          recurrence: parentTask.recurrence,
          weeklyDays: parentTask.weeklyDays,
          endDate: parentTask.endDate,
          completedDates: parentTask.completedDates,
          spaceId: parentTask.spaceId,
          parentTaskId: parentTask.parentTaskId,
          subtaskIds: [...parentTask.subtaskIds, task.id],
          tags: parentTask.tags,
          status: parentTask.status,
          estimatedMinutes: parentTask.estimatedMinutes,
          actualMinutes: parentTask.actualMinutes,
          notes: parentTask.notes,
          attachments: parentTask.attachments,
          customFields: parentTask.customFields,
        ));
      }
    }
  }
  
  static Future<EnhancedTask?> getEnhancedTask(String id) async {
    final tasks = await getAllEnhancedTasks();
    try {
      return tasks.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }
  
  static Future<void> updateEnhancedTask(EnhancedTask task) async {
    final tasks = await getAllEnhancedTasks();
    final index = tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      tasks[index] = task;
      await _saveEnhancedTasks(tasks);
    }
  }
  
  static Future<void> deleteEnhancedTask(String id) async {
    final task = await getEnhancedTask(id);
    if (task == null) return;
    
    // Remove from parent's subtask list if it's a subtask
    if (task.parentTaskId != null) {
      final parentTask = await getEnhancedTask(task.parentTaskId!);
      if (parentTask != null) {
        final updatedSubtasks = List<String>.from(parentTask.subtaskIds)..remove(id);
        await updateEnhancedTask(EnhancedTask(
          id: parentTask.id,
          title: parentTask.title,
          description: parentTask.description,
          createdAt: parentTask.createdAt,
          isCompleted: parentTask.isCompleted,
          priority: parentTask.priority,
          scheduleType: parentTask.scheduleType,
          absoluteTime: parentTask.absoluteTime,
          relatedPrayer: parentTask.relatedPrayer,
          isBeforePrayer: parentTask.isBeforePrayer,
          minutesOffset: parentTask.minutesOffset,
          recurrence: parentTask.recurrence,
          weeklyDays: parentTask.weeklyDays,
          endDate: parentTask.endDate,
          completedDates: parentTask.completedDates,
          spaceId: parentTask.spaceId,
          parentTaskId: parentTask.parentTaskId,
          subtaskIds: updatedSubtasks,
          tags: parentTask.tags,
          status: parentTask.status,
          estimatedMinutes: parentTask.estimatedMinutes,
          actualMinutes: parentTask.actualMinutes,
          notes: parentTask.notes,
          attachments: parentTask.attachments,
          customFields: parentTask.customFields,
        ));
      }
    }
    
    // Remove from space's item list if it belongs to a space
    if (task.spaceId != null) {
      final space = await getSpace(task.spaceId!);
      if (space != null) {
        final updatedItemIds = List<String>.from(space.itemIds)..remove(id);
        await updateSpace(space.copyWith(itemIds: updatedItemIds));
      }
    }
    
    // Delete all subtasks recursively
    for (final subtaskId in task.subtaskIds) {
      await deleteEnhancedTask(subtaskId);
    }
    
    // Finally, delete the task itself
    final tasks = await getAllEnhancedTasks();
    tasks.removeWhere((t) => t.id == id);
    await _saveEnhancedTasks(tasks);
  }
  
  static Future<void> _saveEnhancedTasks(List<EnhancedTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await prefs.setString(_enhancedTasksKey, tasksJson);
  }
  
  // Quick task creation (for dumping ideas)
  static Future<void> quickAddIdea(String title, {String? spaceId, List<String>? tags}) async {
    final task = EnhancedTask.unscheduled(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      spaceId: spaceId,
      tags: tags,
    );
    await createEnhancedTask(task);
  }
  
  // Add task directly to TodoService
  static Future<void> addTask(Task task) async {
    await TodoService.addTask(task);
  }
  
  // Convert idea to scheduled task
  static Future<void> convertToTask(String ideaId) async {
    final idea = await getEnhancedTask(ideaId);
    if (idea == null) return;
    
    // Create a new task in the main todo service
    final task = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: idea.title,
      description: idea.description,
      createdAt: DateTime.now(),
      scheduleType: ScheduleType.absolute,
      recurrence: TaskRecurrence.once,
      priority: idea.priority,
    );
    
    await TodoService.addTask(task);
    
    // Optionally mark the idea as completed or delete it
    await updateEnhancedTask(EnhancedTask(
      id: idea.id,
      title: idea.title,
      description: idea.description,
      createdAt: idea.createdAt,
      isCompleted: true,
      priority: idea.priority,
      scheduleType: idea.scheduleType,
      absoluteTime: idea.absoluteTime,
      relatedPrayer: idea.relatedPrayer,
      isBeforePrayer: idea.isBeforePrayer,
      minutesOffset: idea.minutesOffset,
      recurrence: idea.recurrence,
      weeklyDays: idea.weeklyDays,
      endDate: idea.endDate,
      completedDates: idea.completedDates,
      spaceId: idea.spaceId,
      parentTaskId: idea.parentTaskId,
      subtaskIds: idea.subtaskIds,
      tags: idea.tags,
      status: TaskStatus.done,
      estimatedMinutes: idea.estimatedMinutes,
      actualMinutes: idea.actualMinutes,
      notes: idea.notes,
      attachments: idea.attachments,
      customFields: idea.customFields,
    ));
  }
  
  // Batch operations
  static Future<void> scheduleMultipleTasks(List<String> taskIds, {
    DateTime? absoluteTime,
    PrayerName? relatedPrayer,
    bool? isBeforePrayer,
    int? minutesOffset,
  }) async {
    for (final taskId in taskIds) {
      final task = await getEnhancedTask(taskId);
      if (task != null) {
        final scheduledTask = task.schedule(
          absoluteTime: absoluteTime,
          relatedPrayer: relatedPrayer,
          isBeforePrayer: isBeforePrayer,
          minutesOffset: minutesOffset,
        );
        await updateEnhancedTask(scheduledTask);
      }
    }
  }
  
  // Space progress
  static Future<Map<String, dynamic>> getSpaceProgress(String spaceId, {bool includeSubSpaces = false}) async {
    final tasks = await getSpaceTasks(spaceId);
    var allTasks = List<EnhancedTask>.from(tasks);
    
    // Include tasks from sub-spaces if requested
    if (includeSubSpaces) {
      final space = await getSpace(spaceId);
      if (space != null) {
        for (final subSpaceId in space.subSpaceIds) {
          final subSpaceTasks = await getSpaceTasks(subSpaceId);
          allTasks.addAll(subSpaceTasks);
        }
      }
    }
    
    final total = allTasks.length;
    final completed = allTasks.where((t) => t.status == TaskStatus.done).length;
    final inProgress = allTasks.where((t) => t.status == TaskStatus.inProgress).length;
    final blocked = allTasks.where((t) => t.status == TaskStatus.blocked).length;
    
    return {
      'total': total,
      'completed': completed,
      'inProgress': inProgress,
      'blocked': blocked,
      'percentage': total > 0 ? (completed / total * 100).round() : 0,
    };
  }
  
  // Get total item count including sub-spaces
  static Future<int> getSpaceItemCount(String spaceId, {bool includeSubSpaces = true}) async {
    final directTasks = await getSpaceTasks(spaceId);
    var count = directTasks.length;
    
    if (includeSubSpaces) {
      final space = await getSpace(spaceId);
      if (space != null) {
        for (final subSpaceId in space.subSpaceIds) {
          count += await getSpaceItemCount(subSpaceId, includeSubSpaces: true);
        }
      }
    }
    
    return count;
  }
}