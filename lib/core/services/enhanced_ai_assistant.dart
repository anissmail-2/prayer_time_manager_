import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'gemini_task_assistant.dart';
import 'prayer_time_service.dart';
import 'todo_service.dart';
import 'space_service.dart';
import 'prayer_duration_service.dart';
import '../../models/task.dart';
import '../../models/space.dart';
import '../config/config_loader.dart';

enum ConversationIntent {
  // Task operations
  taskCreation,
  taskDeletion,
  taskUpdate,
  taskView,
  taskComplete,
  taskBulkOperation,
  
  // Space operations
  spaceCreation,
  spaceView,
  spaceUpdate,
  spaceDeletion,
  taskToSpace,
  
  // Analytics & insights
  analytics,
  productivity,
  suggestions,
  
  // Scheduling
  smartScheduling,
  conflictResolution,
  freeTimeQuery,
  
  // General
  generalChat,
  clarification,
  scheduling,
  confirmation,
  greeting,
  planning,
  command,
  help,
}

// Comprehensive context about current state
class AIContext {
  final List<TaskWithTime> allTasks;
  final List<TaskWithTime> todayTasks;
  final List<TaskWithTime> upcomingTasks;
  final List<Space> spaces;
  final Map<String, String> prayerTimes;
  final Map<String, int> prayerDurations;
  final Map<String, dynamic> statistics;
  final List<TimeSlot> freeTimeSlots;
  final DateTime now;
  
  AIContext({
    required this.allTasks,
    required this.todayTasks,
    required this.upcomingTasks,
    required this.spaces,
    required this.prayerTimes,
    required this.prayerDurations,
    required this.statistics,
    required this.freeTimeSlots,
    required this.now,
  });
}

class TimeSlot {
  final DateTime start;
  final DateTime end;
  final String label;
  final int durationMinutes;
  
  TimeSlot({
    required this.start,
    required this.end,
    required this.label,
  }) : durationMinutes = end.difference(start).inMinutes;
}

class TimeBlock {
  final DateTime start;
  final DateTime end;
  final String label;
  
  TimeBlock({
    required this.start,
    required this.end,
    required this.label,
  });
}

class EnhancedAIAssistant {
  static String get _apiKey => ConfigLoader.geminiApiKey;
  static const String _modelName = 'gemini-2.5-flash-lite-preview-06-17';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
  
  // Gather comprehensive context about current state
  static Future<AIContext> _gatherContext() async {
    final now = DateTime.now();
    final prayerTimes = await PrayerTimeService.getPrayerTimes();
    final prayerDurationsMap = await PrayerDurationService.getAllDurations();
    final prayerDurations = <String, int>{};
    prayerDurationsMap.forEach((prayer, duration) {
      final key = prayer.toString().split('.').last;
      prayerDurations[key] = duration.minutesBefore + duration.minutesAfter;
    });
    final allTasks = await TodoService.getAllTasksWithTimes(prayerTimes);
    final spaces = await SpaceService.getAllSpaces();
    
    // Filter today's tasks
    final todayTasks = allTasks.where((t) => 
      t.task.shouldShowToday(now) && !t.task.isCompletedForDate(now)
    ).toList();
    
    // Filter upcoming tasks
    final upcomingTasks = allTasks.where((t) => 
      t.scheduledTime.isAfter(now) &&
      !t.task.isCompletedForDate(now)
    ).toList();
    
    // Calculate statistics
    final statistics = {
      'total_tasks': allTasks.length,
      'today_tasks': todayTasks.length,
      'completed_today': allTasks.where((t) => t.task.isCompletedToday()).length,
      'high_priority': allTasks.where((t) => t.task.priority == TaskPriority.high && !t.task.isCompletedToday()).length,
      'spaces': spaces.length,
      'tasks_by_space': _getTasksBySpace(allTasks, spaces),
      'completion_rate': _calculateCompletionRate(allTasks),
      'busiest_time': _findBusiestTime(todayTasks),
    };
    
    // Calculate free time slots
    final freeTimeSlots = await _calculateFreeTimeSlots(
      prayerTimes, 
      prayerDurations, 
      todayTasks,
      now);
    
    return AIContext(
      allTasks: allTasks,
      todayTasks: todayTasks,
      upcomingTasks: upcomingTasks,
      spaces: spaces,
      prayerTimes: prayerTimes,
      prayerDurations: prayerDurations,
      statistics: statistics,
      freeTimeSlots: freeTimeSlots,
      now: now);
  }
  
  // Calculate free time slots between prayers and tasks
  static Future<List<TimeSlot>> _calculateFreeTimeSlots(
    Map<String, String> prayerTimes,
    Map<String, int> prayerDurations,
    List<TaskWithTime> todayTasks,
    DateTime now) async {
    final slots = <TimeSlot>[];
    
    // Create prayer blocks
    final prayerBlocks = <TimeBlock>[];
    for (final prayer in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      final timeStr = prayerTimes[prayer];
      if (timeStr != null) {
        final parts = timeStr.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          if (hour != null && minute != null) {
            final prayerTime = DateTime(now.year, now.month, now.day, hour, minute);
            final duration = prayerDurations[prayer.toLowerCase()] ?? 15;
            prayerBlocks.add(TimeBlock(
              start: prayerTime,
              end: prayerTime.add(Duration(minutes: duration)),
              label: '$prayer prayer'));
          }
        }
      }
    }
    
    // Sort prayer blocks by time
    prayerBlocks.sort((a, b) => a.start.compareTo(b.start));
    
    // Find free slots between prayers
    for (int i = 0; i < prayerBlocks.length - 1; i++) {
      final currentEnd = prayerBlocks[i].end;
      final nextStart = prayerBlocks[i + 1].start;
      final duration = nextStart.difference(currentEnd).inMinutes;
      
      if (duration > 20) { // At least 20 minutes free
        // Check if any tasks occupy this slot
        final tasksInSlot = todayTasks.where((t) =>
          t.scheduledTime.isAfter(currentEnd) &&
          t.scheduledTime.isBefore(nextStart)
        ).toList();
        
        if (tasksInSlot.isEmpty) {
          slots.add(TimeSlot(
            start: currentEnd,
            end: nextStart,
            label: 'Free after ${prayerBlocks[i].label}'));
        } else {
          // Calculate free time around tasks
          var slotStart = currentEnd;
          for (final task in tasksInSlot) {
            final taskStart = task.scheduledTime;
            final gap = taskStart.difference(slotStart).inMinutes;
            if (gap > 20) {
              slots.add(TimeSlot(
                start: slotStart,
                end: taskStart,
                label: 'Free time'));
            }
            // Assume task takes 30 minutes
            slotStart = taskStart.add(const Duration(minutes: 30));
          }
          
          // Check remaining time after last task
          final remainingTime = nextStart.difference(slotStart).inMinutes;
          if (remainingTime > 20) {
            slots.add(TimeSlot(
              start: slotStart,
              end: nextStart,
              label: 'Free before ${prayerBlocks[i + 1].label}'));
          }
        }
      }
    }
    
    return slots;
  }
  
  // Track last suggestions to allow updates
  static List<TaskSuggestion>? _lastSuggestions;
  static SpaceSuggestion? _lastSpaceSuggestion;
  static String? _lastCreatedSpaceId;
  static String? _lastCreatedSpaceName;
  static bool _pendingSpaceCreation = false;
  
  // Update last created space
  static void updateLastCreatedSpace(String id, String name) {
    _lastCreatedSpaceId = id;
    _lastCreatedSpaceName = name;
  }
  
  // Main processing function with full execution capabilities
  static Future<AIResponse> processMessage(
    String userMessage,
    List<dynamic> conversationHistory) async {
    try {
      // Check if API key is available
      if (!ConfigLoader.hasValidGeminiKey) {
        return AIResponse(
          message: 'AI service is not configured. Please check your API key settings.',
          intent: ConversationIntent.generalChat,
        );
      }
      
      // Gather comprehensive context
      final context = await _gatherContext();
      
      // Check if this is a response to a space name request
      if (_pendingSpaceCreation) {
        // Check if user is providing a space name (short response) or changing topic
        final words = userMessage.trim().split(' ');
        if (words.length <= 4 && !userMessage.toLowerCase().contains('create') && 
            !userMessage.toLowerCase().contains('task') && 
            !userMessage.toLowerCase().contains('show')) {
          // User is providing a space name
          final spaceName = userMessage.trim();
          final spaceAnalysis = ConversationAnalysis(
            intent: ConversationIntent.spaceCreation,
            confidence: 0.9,
            entities: {
              'space_info': {'name': spaceName}
            }
          );
          return await _handleSpaceCreation(spaceAnalysis, context);
        } else {
          // User changed topic, clear the pending flag
          _pendingSpaceCreation = false;
        }
      }
      
      // Analyze user intent with last suggestions context
      final analysis = await _analyzeMessage(userMessage, conversationHistory, context);
      
      // Execute operations based on intent
      switch (analysis.intent) {
        // Task operations
        case ConversationIntent.taskCreation:
          return await _handleTaskCreation(analysis, context);
          
        case ConversationIntent.taskDeletion:
          return await _handleTaskDeletion(analysis, context);
          
        case ConversationIntent.taskUpdate:
          return await _handleTaskUpdate(analysis, context);
          
        case ConversationIntent.taskView:
          return await _handleTaskView(analysis, context);
          
        case ConversationIntent.taskComplete:
          return await _handleTaskComplete(analysis, context);
          
        case ConversationIntent.taskBulkOperation:
          return await _handleBulkTaskCreation(analysis, context);
          
        // Space operations
        case ConversationIntent.spaceCreation:
          return await _handleSpaceCreation(analysis, context);
          
        case ConversationIntent.spaceView:
          return await _handleSpaceView(analysis, context);
          
        case ConversationIntent.taskToSpace:
          return await _handleTaskToSpace(analysis, context);
          
        // Analytics & insights
        case ConversationIntent.analytics:
          return await _handleAnalytics(analysis, context);
          
        case ConversationIntent.productivity:
          return await _handleProductivityInsights(analysis, context);
          
        // Scheduling
        case ConversationIntent.smartScheduling:
          return await _handleSmartScheduling(analysis, context);
          
        case ConversationIntent.freeTimeQuery:
          return await _handleFreeTimeQuery(analysis, context);
          
        // General conversation
        default:
          return await _handleGeneralConversation(userMessage, analysis, context, conversationHistory);
      }
    } catch (e) {
      return AIResponse(
        message: "Sorry, I didn't quite understand that. Could you rephrase what you'd like me to do?",
        intent: ConversationIntent.generalChat,
        error: e.toString());
    }
  }
  
  // Analyze message with context awareness
  static Future<ConversationAnalysis> _analyzeMessage(
    String message,
    List<dynamic> history,
    AIContext context) async {
    // Check if there are recent task suggestions to refer to
    final hasRecentSuggestions = _lastSuggestions != null && _lastSuggestions!.isNotEmpty;
    final lastSuggestionInfo = hasRecentSuggestions 
        ? "\nLast task suggestion: ${_lastSuggestions!.first.title} at ${_lastSuggestions!.first.absoluteTime ?? 'unspecified time'}"
        : "";
    
    // Check for recent space creation
    final lastSpaceInfo = _lastCreatedSpaceName != null
        ? "\nLast created space: $_lastCreatedSpaceName"
        : "";
    
    // Add current date/time context
    final now = DateTime.now();
    final currentDateStr = DateFormat('EEEE, MMMM d, yyyy').format(now);
    final currentTimeStr = DateFormat('h:mm a').format(now);
    
    // Get prayer times for context
    final prayerTimes = context.prayerTimes;
    final prayerTimesStr = prayerTimes.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    
    final prompt = '''
Analyze this message for a task management app.

CURRENT CONTEXT:
- Today's date: $currentDateStr
- Current time: $currentTimeStr
- Day of week: ${DateFormat('EEEE').format(now)}
- Prayer times: $prayerTimesStr

User message: "$message"

Recent conversation: 
${history.take(5).where((m) => m.text != null && m.text.isNotEmpty).map((m) => '${m.isUser ? "User" : "AI"}: ${m.text}').join('\n')}
$lastSuggestionInfo
$lastSpaceInfo

Determine the user intent and extract information. Be flexible with natural language.

Examples:
- Task creation with various time formats -> task_creation
- Renaming or updating task properties -> task_update 
- Changing time to prayer times -> task_update with prayer name as end_time
- Viewing tasks -> task_view
- Creating spaces -> space_creation
- Bulk task operations -> task_bulk_operation

Important rules:
1. If user is naming/renaming and there's a recent task suggestion, it's a task_update for that suggestion
2. "it", "that", "the task" refer to the last task suggestion if one exists
3. If updating a suggested task that hasn't been created yet, use "__pending_suggestion__" as task_identifier
4. Recurrence options: "once", "daily", "weekly", "monthly"
5. For space creation, extract the space name from phrases like "called", "named", etc.
6. If user provides just a single word/phrase after being asked for a space name, it's the space name
7. "that space", "the space you just created", "it" can refer to the last created space - use the space name from context
8. When user mentions "until [prayer]" or "to [prayer]", extract the prayer name as end_time
9. Prayer names for end_time: fajr, sunrise, dhuhr, asr, maghrib, isha
10. IMPORTANT: For times with "am", use 24hr format (3am = "03:00", 11am = "11:00")
11. IMPORTANT: For times with "pm", use 24hr format (3pm = "15:00", 11pm = "23:00")
12. Date indicators: "tmw"/"tomorrow" = "tomorrow", "today" = "today"

Context:
- Pending space creation: $_pendingSpaceCreation

Return JSON:
{
  "intent": "task_creation|task_deletion|task_update|task_view|task_complete|task_bulk_operation|space_creation|analytics|general_chat",
  "confidence": 0.0-1.0,
  "entities": {
    "task_info": {
      "title": "task name if mentioned",
      "time": "start time if mentioned (use 24hr format for am/pm)",
      "end_time": "end time if mentioned (from X to Y patterns)", 
      "date": "today/tomorrow/specific date if mentioned",
      "priority": "high/medium/low",
      "description": "any extra details",
      "recurrence": "once/daily/weekly/monthly",
      "space": "space name or reference if tasks should be in a space"
    },
    "space_info": {
      "name": "space name if mentioned",
      "color": "color if mentioned",
      "description": "space description if provided"
    },
    "bulk_operation": {
      "count": "number of tasks to create",
      "space": "space name for bulk operations"
    },
    "task_identifier": "which task to update/delete (use __pending_suggestion__ for last suggestion)",
    "update_fields": {"title": "new name", "priority": "new value", "time": "new time", "end_time": "new end time", "recurrence": "new recurrence"}
  },
  "missing_info": ["what's missing to complete the action"]
}

Always check conversation history and last suggestions to understand context.
''';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/$_modelName:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{
            'parts': [{'text': prompt}]
          }]
        }));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseText = data['candidates'][0]['content']['parts'][0]['text'];
        return _parseAnalysis(responseText);
      }
    } catch (e) {
      // Fallback
    }
    
    return ConversationAnalysis(
      intent: ConversationIntent.generalChat,
      confidence: 0.5,
      entities: {});
  }
  
  // Handle bulk task creation
  static Future<AIResponse> _handleBulkTaskCreation(
    ConversationAnalysis analysis,
    AIContext context) async {
    final bulkInfo = analysis.entities['bulk_operation'] ?? {};
    final spaceName = bulkInfo['space']?.toString();
    final count = int.tryParse(bulkInfo['count']?.toString() ?? '') ?? 3;
    
    if (spaceName == null) {
      return AIResponse(
        message: "Which space would you like to add these tasks to?",
        intent: ConversationIntent.taskBulkOperation,
        needsConfirmation: false
      );
    }
    
    // Find matching space - case insensitive
    final spaceNameLower = spaceName.toLowerCase();
    final matchingSpaces = context.spaces.where((p) => 
      p.name.toLowerCase() == spaceNameLower ||
      p.name.toLowerCase().contains(spaceNameLower) ||
      (spaceNameLower.length == 1 && p.name.toLowerCase().endsWith(spaceNameLower))
    ).toList();
    
    if (matchingSpaces.isEmpty) {
      return AIResponse(
        message: "I couldn't find a space matching '$spaceName'. Here are your current spaces:",
        intent: ConversationIntent.taskBulkOperation,
        spaceList: context.spaces
      );
    }
    
    // If exact match exists, prefer it
    final exactMatch = matchingSpaces.firstWhere(
      (p) => p.name.toLowerCase() == spaceNameLower,
      orElse: () => matchingSpaces.first
    );
    
    if (matchingSpaces.length > 1 && exactMatch.name.toLowerCase() != spaceNameLower) {
      return AIResponse(
        message: "I found multiple spaces matching '$spaceName'. Which one did you mean?",
        intent: ConversationIntent.taskBulkOperation,
        spaceList: matchingSpaces
      );
    }
    
    final space = exactMatch;
    final spaceId = space.id;
    
    // Generate multiple task suggestions
    final suggestions = <TaskSuggestion>[];
    final now = DateTime.now();
    
    for (int i = 0; i < count; i++) {
      final taskNumber = i + 1;
      final timeOffset = 30 * i; // Space tasks 30 minutes apart
      final taskTime = now.add(Duration(hours: 1, minutes: timeOffset));
      
      suggestions.add(TaskSuggestion(
        title: 'Task $taskNumber for ${space.name}',
        description: 'Task created for ${space.name} #$spaceId',
        scheduleType: 'absolute',
        absoluteTime: '${taskTime.hour}:${taskTime.minute.toString().padLeft(2, '0')}',
        recurrenceType: 'once',
        priority: TaskPriority.medium,
      ));
    }
    
    _lastSuggestions = suggestions;
    
    return AIResponse(
      message: "I've prepared $count tasks for ${space.name}. You can edit them before adding:",
      intent: ConversationIntent.taskBulkOperation,
      suggestions: suggestions,
      needsConfirmation: true
    );
  }
  
  // Execute task creation with space awareness
  static Future<AIResponse> _handleTaskCreation(
    ConversationAnalysis analysis,
    AIContext context) async {
    final taskInfo = analysis.entities['task_info'] ?? {};
    final missingInfo = analysis.missingInfo;
    
    // For simple task creation requests, try to proceed even with minimal info
    if (missingInfo.isNotEmpty && taskInfo['time'] == null) {
      // Only ask for missing info if we really need it
      final questions = _generateClarifyingQuestions(missingInfo, context);
      return AIResponse(
        message: "I'd be happy to create that task for you. ${questions.join(' ')}",
        intent: ConversationIntent.taskCreation,
        suggestedQuestions: analysis.suggestions);
    }
    
    // Check if task should be in a space
    String? spaceId;
    if (taskInfo['space'] != null) {
      final spaceName = taskInfo['space'].toString().toLowerCase();
      final space = context.spaces.firstWhere(
        (p) => p.name.toLowerCase().contains(spaceName),
        orElse: () => Space(id: '', name: '', color: 'blue', createdAt: DateTime.now()));
      if (space.id.isNotEmpty) {
        spaceId = space.id;
      }
    }
    
    // Ensure we have at least a basic title
    if (taskInfo['title'] == null && taskInfo['time'] != null) {
      taskInfo['title'] = 'Task';
    }
    
    // Convert prayer names to actual times if needed
    if (taskInfo['end_time'] != null) {
      final prayerNames = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
      final endTimeStr = taskInfo['end_time'].toString().toLowerCase();
      if (prayerNames.contains(endTimeStr)) {
        // Get the actual prayer time from context
        final prayerKey = endTimeStr.substring(0, 1).toUpperCase() + endTimeStr.substring(1);
        final prayerTimeStr = context.prayerTimes[prayerKey];
        if (prayerTimeStr != null) {
          // Save the original prayer name for reference
          taskInfo['original_end_time'] = taskInfo['end_time'];
          taskInfo['end_time'] = prayerTimeStr;
        }
      }
    }
    
    // Generate task suggestions with Gemini
    final suggestions = await GeminiTaskAssistant.getTaskSuggestions(
      _buildTaskRequest(taskInfo));
    
    // If we have endTime or date in taskInfo, make sure they're preserved in suggestions
    if ((taskInfo['end_time'] != null || taskInfo['date'] != null) && suggestions.isNotEmpty) {
      for (var i = 0; i < suggestions.length; i++) {
        if (suggestions[i].endTime == null || suggestions[i].taskDate == null) {
          // Create a new suggestion with endTime and date
          suggestions[i] = TaskSuggestion(
            title: suggestions[i].title,
            description: suggestions[i].description,
            scheduleType: suggestions[i].scheduleType,
            absoluteTime: suggestions[i].absoluteTime,
            endTime: taskInfo['end_time']?.toString() ?? suggestions[i].endTime,
            taskDate: taskInfo['date']?.toString() ?? suggestions[i].taskDate,
            relatedPrayer: suggestions[i].relatedPrayer,
            isBeforePrayer: suggestions[i].isBeforePrayer,
            minutesOffset: suggestions[i].minutesOffset,
            recurrenceType: suggestions[i].recurrenceType,
            priority: suggestions[i].priority,
            weeklyDays: suggestions[i].weeklyDays,
            endDate: suggestions[i].endDate,
            reasoningNotes: suggestions[i].reasoningNotes,
            energyLevel: suggestions[i].energyLevel,
          );
        }
      }
    }
    
    // Add space tag if needed
    if (spaceId != null && suggestions.isNotEmpty) {
      for (var suggestion in suggestions) {
        final desc = suggestion.description ?? '';
        final newDesc = desc.isEmpty ? '#$spaceId' : '$desc #$spaceId';
        // Create a new suggestion with the updated description
        suggestions[suggestions.indexOf(suggestion)] = TaskSuggestion(
          title: suggestion.title,
          description: newDesc,
          scheduleType: suggestion.scheduleType,
          absoluteTime: suggestion.absoluteTime,
          relatedPrayer: suggestion.relatedPrayer,
          isBeforePrayer: suggestion.isBeforePrayer,
          minutesOffset: suggestion.minutesOffset,
          recurrenceType: suggestion.recurrenceType,
          priority: suggestion.priority,
          weeklyDays: suggestion.weeklyDays,
          endDate: suggestion.endDate,
          reasoningNotes: suggestion.reasoningNotes,
          energyLevel: suggestion.energyLevel);
      }
    }
    
    // Store suggestions for potential updates
    _lastSuggestions = suggestions;
    
    return AIResponse(
      message: "I've set up your task. Just click the ✓ button below to add it to your schedule:",
      intent: ConversationIntent.taskCreation,
      suggestions: suggestions,
      needsConfirmation: true);
  }
  
  // Execute task deletion
  static Future<AIResponse> _handleTaskDeletion(
    ConversationAnalysis analysis,
    AIContext context) async {
    final identifier = analysis.entities['task_identifier'];
    if (identifier == null) {
      return AIResponse(
        message: "Which task would you like to delete? You can tell me the task name or describe it.",
        intent: ConversationIntent.taskDeletion,
);
    }
    
    // Find matching tasks
    final matches = context.allTasks.where((t) =>
      t.task.title.toLowerCase().contains(identifier.toString().toLowerCase()) ||
      (t.task.description?.toLowerCase().contains(identifier.toString().toLowerCase()) ?? false)
    ).toList();
    
    if (matches.isEmpty) {
      return AIResponse(
        message: "I couldn't find a task matching '$identifier'. Here are your current tasks:",
        intent: ConversationIntent.taskDeletion,
        taskList: context.todayTasks.take(5).toList());
    }
    
    if (matches.length == 1) {
      // Delete the task
      await TodoService.deleteTask(matches.first.task.id);
      return AIResponse(
        message: "✅ I've deleted '${matches.first.task.title}' successfully.",
        intent: ConversationIntent.taskDeletion,
        success: true);
    }
    
    // Multiple matches
    return AIResponse(
      message: "I found ${matches.length} tasks matching '$identifier'. Which one would you like to delete?",
      intent: ConversationIntent.taskDeletion,
      taskList: matches,
      needsConfirmation: true);
  }
  
  // View tasks with smart filtering
  static Future<AIResponse> _handleTaskView(
    ConversationAnalysis analysis,
    AIContext context) async {
    final queryParams = analysis.entities['query_params'] ?? {};
    final scope = queryParams['scope'] ?? 'today';
    
    List<TaskWithTime> tasks;
    String description;
    
    switch (scope) {
      case 'all':
        tasks = context.allTasks;
        description = "all your tasks";
        break;
      case 'upcoming':
        tasks = context.upcomingTasks;
        description = "your upcoming tasks";
        break;
      case 'completed':
        tasks = context.allTasks.where((t) => t.task.isCompletedToday()).toList();
        description = "tasks you've completed today";
        break;
      default:
        if (scope.startsWith('space_')) {
          // Show tasks for specific space
          final spaceId = scope.substring(8);
          tasks = context.allTasks.where((t) =>
            t.task.description?.contains('#$spaceId') ?? false
          ).toList();
          final space = context.spaces.firstWhere(
            (p) => p.id == spaceId,
            orElse: () => Space(id: '', name: scope, color: 'blue', createdAt: DateTime.now()));
          description = "tasks in ${space.name}";
        } else {
          tasks = context.todayTasks;
          description = "your tasks for today";
        }
    }
    
    if (tasks.isEmpty) {
      return AIResponse(
        message: "You don't have any ${description.contains('today') ? 'tasks scheduled for today' : description}. Would you like to create one?",
        intent: ConversationIntent.taskView
      );
    }
    
    // Group by priority or time
    final highPriority = tasks.where((t) => t.task.priority == TaskPriority.high).toList();
    final message = StringBuffer("Here are $description:\n\n");
    
    if (highPriority.isNotEmpty) {
      message.writeln("🔴 **High Priority:**");
      for (var t in highPriority) {
        message.writeln("• ${t.task.title} - ${_formatTaskTime(t, context)}");
      }
      message.writeln();
    }
    
    return AIResponse(
      message: message.toString(),
      intent: ConversationIntent.taskView,
      taskList: tasks,
      statistics: {
        'total': tasks.length,
        'high_priority': highPriority.length,
        'completed': tasks.where((t) => t.task.isCompletedToday()).length,
      });
  }
  
  // Handle space operations
  static Future<AIResponse> _handleSpaceCreation(
    ConversationAnalysis analysis,
    AIContext context) async {
    final spaceInfo = analysis.entities['space_info'] ?? {};
    
    if (spaceInfo['name'] == null) {
      _pendingSpaceCreation = true;
      return AIResponse(
        message: "What would you like to name your new space?",
        intent: ConversationIntent.spaceCreation
      );
    }
    
    final name = spaceInfo['name'].toString();
    final color = spaceInfo['color']?.toString() ?? _getRandomColor();
    final description = spaceInfo['description']?.toString() ?? '';
    
    // Create space suggestion for confirmation
    final spaceSuggestion = SpaceSuggestion(
      name: name,
      color: color,
      description: description,
    );
    
    _lastSpaceSuggestion = spaceSuggestion;
    _lastCreatedSpaceName = name;
    _pendingSpaceCreation = false;
    
    return AIResponse(
      message: "I've prepared your space. Click the ✓ button below to create it:",
      intent: ConversationIntent.spaceCreation,
      spaceSuggestions: [spaceSuggestion],
      needsConfirmation: true
    );
  }
  
  // View spaces with statistics
  static Future<AIResponse> _handleSpaceView(
    ConversationAnalysis analysis,
    AIContext context) async {
    if (context.spaces.isEmpty) {
      return AIResponse(
        message: "You don't have any spaces yet. Would you like to create one to organize your tasks?",
        intent: ConversationIntent.spaceView
      );
    }
    
    final spaceStats = <String, Map<String, int>>{};
    for (var space in context.spaces) {
      final spaceTasks = context.allTasks.where((t) =>
        t.task.description?.contains('#${space.id}') ?? false
      ).toList();
      
      spaceStats[space.id] = {
        'total': spaceTasks.length,
        'completed': spaceTasks.where((t) => t.task.isCompletedToday()).length,
        'pending': spaceTasks.where((t) => !t.task.isCompletedToday()).length,
      };
    }
    
    final message = StringBuffer("Here are your spaces:\n\n");
    for (var space in context.spaces) {
      final stats = spaceStats[space.id]!;
      message.writeln("📁 **${space.name}** (${space.color})");
      message.writeln("   ${stats['pending']} pending, ${stats['completed']} completed today");
    }
    
    return AIResponse(
      message: message.toString(),
      intent: ConversationIntent.spaceView,
      spaceList: context.spaces,
      statistics: spaceStats
    );
  }
  
  // Analytics and insights
  static Future<AIResponse> _handleAnalytics(
    ConversationAnalysis analysis,
    AIContext context) async {
    final stats = context.statistics;
    final completionRate = stats['completion_rate'] ?? 0;
    final busiestTime = stats['busiest_time'] ?? 'Unknown';
    
    final insights = StringBuffer("📊 **Your Task Analytics:**\n\n");
    
    insights.writeln("**Today's Progress:**");
    insights.writeln("• ${stats['completed_today']}/${stats['today_tasks']} tasks completed (${(completionRate * 100).toStringAsFixed(0)}%)");
    insights.writeln("• ${stats['high_priority']} high-priority tasks pending");
    insights.writeln();
    
    insights.writeln("**Overall Statistics:**");
    insights.writeln("• Total tasks: ${stats['total_tasks']}");
    insights.writeln("• Active spaces: ${stats['spaces']}");
    insights.writeln("• Busiest time: $busiestTime");
    insights.writeln();
    
    // Productivity insights
    if (completionRate < 0.5) {
      insights.writeln("💡 **Suggestion:** Your completion rate is below 50%. Consider:");
      insights.writeln("• Breaking large tasks into smaller ones");
      insights.writeln("• Scheduling tasks during your free time slots");
      insights.writeln("• Using the Pomodoro technique");
    }
    
    return AIResponse(
      message: insights.toString(),
      intent: ConversationIntent.analytics,
      statistics: stats
    );
  }
  
  // Smart scheduling with prayer awareness
  static Future<AIResponse> _handleSmartScheduling(
    ConversationAnalysis analysis,
    AIContext context) async {
    final taskInfo = analysis.entities['task_info'] ?? {};
    final duration = int.tryParse(taskInfo['duration']?.toString() ?? '30') ?? 30;
    
    // Find optimal time slots
    final optimalSlots = <String>[];
    for (var slot in context.freeTimeSlots) {
      if (slot.durationMinutes >= duration) {
        final timeStr = DateFormat('h:mm a').format(slot.start);
        optimalSlots.add("$timeStr (${slot.durationMinutes} min available ${slot.label})");
      }
    }
    
    if (optimalSlots.isEmpty) {
      return AIResponse(
        message: "Your schedule is quite full today. Would you like me to find time tomorrow or suggest shorter tasks?",
        intent: ConversationIntent.smartScheduling
      );
    }
    
    return AIResponse(
      message: "Based on your prayer schedule and existing tasks, here are the best times for a $duration-minute task:\n\n${optimalSlots.map((s) => '• $s').join('\n')}",
      intent: ConversationIntent.smartScheduling,
      freeTimeSlots: context.freeTimeSlots
    );
  }
  
  // Handle general conversation with context
  static Future<AIResponse> _handleGeneralConversation(
    String userMessage,
    ConversationAnalysis analysis,
    AIContext context,
    List<dynamic> conversationHistory) async {
    // Build conversation history in Gemini format
    final geminiHistory = <Map<String, dynamic>>[];
    
    // Add system context with current date/time
    final now = DateTime.now();
    final currentDateStr = DateFormat('EEEE, MMMM d, yyyy').format(now);
    final currentTimeStr = DateFormat('h:mm a').format(now);
    
    geminiHistory.add({
      'role': 'user',
      'parts': [{
        'text': '''You are a helpful AI assistant for a task management app. 

CURRENT CONTEXT:
- Today's date: $currentDateStr
- Current time: $currentTimeStr
- Day of week: ${DateFormat('EEEE').format(now)}

You should remember the conversation context and respond naturally.
Be consistent with previous messages in the conversation.
If someone asks what you said or meant, refer to the actual conversation history.
IMPORTANT: When you can't perform a requested action, be honest and say so clearly.
Don't pretend to do things you cannot do. If a feature isn't available, say so.'''
      }]
    });
    
    geminiHistory.add({
      'role': 'model',
      'parts': [{'text': 'I understand. I\'ll maintain conversation context, respond consistently, and be honest about what I can and cannot do.'}]
    });
    
    // Convert conversation history to Gemini format
    for (final msg in conversationHistory.take(10)) {
      if (msg.text != null && msg.text.isNotEmpty) {
        geminiHistory.add({
          'role': msg.isUser ? 'user' : 'model',
          'parts': [{'text': msg.text}]
        });
      }
    }
    
    // Add current message
    geminiHistory.add({
      'role': 'user',
      'parts': [{'text': userMessage}]
    });
    
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/$_modelName:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': geminiHistory,
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 512,
          }
        }));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseText = data['candidates'][0]['content']['parts'][0]['text'];
        
        return AIResponse(
          message: responseText,
          intent: analysis.intent,
          suggestedQuestions: analysis.suggestions);
      }
    } catch (e) {
      // Error handling
    }
    
    // If Gemini fails, use a fallback with context awareness
    return AIResponse(
      message: "I apologize, I'm having trouble connecting to my AI service. Could you please try again?",
      intent: ConversationIntent.generalChat
    );
  }
  
  // Helper functions
  static Map<String, int> _getTasksBySpace(List<TaskWithTime> tasks, List<Space> spaces) {
    final tasksBySpace = <String, int>{};
    for (var space in spaces) {
      tasksBySpace[space.name] = tasks.where((t) =>
        t.task.description?.contains('#${space.id}') ?? false
      ).length;
    }
    return tasksBySpace;
  }
  
  static double _calculateCompletionRate(List<TaskWithTime> tasks) {
    if (tasks.isEmpty) return 0.0;
    final completed = tasks.where((t) => t.task.isCompletedToday()).length;
    return completed / tasks.length;
  }
  
  static String _findBusiestTime(List<TaskWithTime> tasks) {
    final hourCounts = <int, int>{};
    for (var task in tasks) {
      final hour = task.scheduledTime.hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
        }
    if (hourCounts.isEmpty) return "No scheduled tasks";
    
    final busiestHour = hourCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    return "${busiestHour.toString().padLeft(2, '0')}:00";
  }
  
  static String _getNextPrayer(Map<String, String> prayerTimes, DateTime now) {
    final prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    for (var prayer in prayers) {
      final timeStr = prayerTimes[prayer];
      if (timeStr != null) {
        final parts = timeStr.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          if (hour != null && minute != null) {
            final prayerTime = DateTime(now.year, now.month, now.day, hour, minute);
            if (prayerTime.isAfter(now)) {
              return "$prayer at $timeStr";
            }
          }
        }
      }
    }
    return "Fajr tomorrow";
  }
  
  static List<String> _generateClarifyingQuestions(List<String> missingInfo, AIContext context) {
    final questions = <String>[];
    
    if (missingInfo.contains('timing')) {
      questions.add("When would you like to schedule this?");
      if (context.freeTimeSlots.isNotEmpty) {
        final nextSlot = context.freeTimeSlots.first;
        questions.add("I have ${nextSlot.durationMinutes} minutes free ${nextSlot.label}.");
      }
    }
    
    if (missingInfo.contains('space')) {
      questions.add("Would you like to add this to a space?");
    }
    
    if (missingInfo.contains('priority')) {
      questions.add("What priority should this have?");
    }
    
    return questions;
  }
  
  static String _formatTaskTime(TaskWithTime task, AIContext context) {
    final time = task.scheduledTime;
    final timeStr = DateFormat('h:mm a').format(time);
    
    // Check if it's near a prayer time
    for (var prayer in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      final prayerTimeStr = context.prayerTimes[prayer];
      if (prayerTimeStr != null) {
        final parts = prayerTimeStr.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          if (hour != null && minute != null) {
            final prayerTime = DateTime(time.year, time.month, time.day, hour, minute);
            final diff = time.difference(prayerTime).inMinutes.abs();
            if (diff <= 30) {
              final relation = time.isBefore(prayerTime) ? "before" : "after";
              return "$timeStr ($diff min $relation $prayer)";
            }
          }
        }
      }
    }
    
    return timeStr;
  }
  
  static String _buildTaskRequest(Map<String, dynamic> taskInfo) {
    final buffer = StringBuffer();
    
    if (taskInfo['title'] != null) {
      buffer.write('Create a task: ${taskInfo['title']}. ');
    }
    
    if (taskInfo['description'] != null) {
      buffer.write('${taskInfo['description']}. ');
    }
    
    // Include date information
    if (taskInfo['date'] != null) {
      buffer.write('Schedule for ${taskInfo['date']}. ');
    } else if (!taskInfo.containsKey('date')) {
      // If no date specified, explicitly mention today
      buffer.write('Schedule for today. ');
    }
    
    if (taskInfo['time'] != null && taskInfo['end_time'] != null) {
      // Check if end_time was originally a prayer name
      final originalEndTime = taskInfo['original_end_time'] ?? taskInfo['end_time'];
      if (originalEndTime != taskInfo['end_time']) {
        buffer.write('From ${taskInfo['time']} to $originalEndTime (${taskInfo['end_time']}). ');
      } else {
        buffer.write('From ${taskInfo['time']} to ${taskInfo['end_time']}. ');
      }
    } else if (taskInfo['time'] != null) {
      buffer.write('At ${taskInfo['time']}. ');
    } else if (taskInfo['timing'] != null) {
      buffer.write('${taskInfo['timing']}. ');
    }
    
    if (taskInfo['recurrence'] != null) {
      buffer.write('Make it ${taskInfo['recurrence']}. ');
    }
    
    if (taskInfo['priority'] != null) {
      buffer.write('Priority: ${taskInfo['priority']}. ');
    }
    
    return buffer.toString();
  }
  
  static String _getRandomColor() {
    final colors = ['blue', 'green', 'purple', 'orange', 'pink', 'teal', 'red', 'indigo'];
    return colors[Random().nextInt(colors.length)];
  }
  
  static TaskPriority _parsePriority(String priorityStr) {
    final priority = priorityStr.toLowerCase();
    if (priority.contains('high') || priority.contains('urgent')) {
      return TaskPriority.high;
    } else if (priority.contains('low')) {
      return TaskPriority.low;
    } else {
      return TaskPriority.medium;
    }
  }
  
  static ConversationAnalysis _parseAnalysis(String response) {
    try {
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch != null) {
        final json = jsonDecode(jsonMatch.group(0)!);
        
        // Map intent string to enum
        ConversationIntent intent = ConversationIntent.generalChat;
        final intentMap = {
          'task_creation': ConversationIntent.taskCreation,
          'task_deletion': ConversationIntent.taskDeletion,
          'task_update': ConversationIntent.taskUpdate,
          'task_view': ConversationIntent.taskView,
          'task_complete': ConversationIntent.taskComplete,
          'task_bulk_operation': ConversationIntent.taskBulkOperation,
          'space_creation': ConversationIntent.spaceCreation,
          'space_view': ConversationIntent.spaceView,
          'space_update': ConversationIntent.spaceUpdate,
          'space_deletion': ConversationIntent.spaceDeletion,
          'task_to_space': ConversationIntent.taskToSpace,
          'analytics': ConversationIntent.analytics,
          'productivity': ConversationIntent.productivity,
          'smart_scheduling': ConversationIntent.smartScheduling,
          'free_time_query': ConversationIntent.freeTimeQuery,
          'general_chat': ConversationIntent.generalChat,
          'greeting': ConversationIntent.greeting,
          'help': ConversationIntent.help,
        };
        
        intent = intentMap[json['intent']] ?? ConversationIntent.generalChat;
        
        return ConversationAnalysis(
          intent: intent,
          confidence: (json['confidence'] ?? 0.5).toDouble(),
          entities: json['entities'] ?? {},
          missingInfo: List<String>.from(json['missing_info'] ?? []),
          suggestions: List<String>.from(json['suggestions'] ?? []));
      }
    } catch (e) {
      // Parse error
    }
    
    return ConversationAnalysis(
      intent: ConversationIntent.generalChat,
      confidence: 0.5,
      entities: {});
  }
  
  // Additional handler methods
  static Future<AIResponse> _handleTaskUpdate(
    ConversationAnalysis analysis,
    AIContext context) async {
    var identifier = analysis.entities['task_identifier'];
    final updateFields = analysis.entities['update_fields'] ?? {};
    
    // Check if updating a pending suggestion
    if (identifier == '__pending_suggestion__' && _lastSuggestions != null && _lastSuggestions!.isNotEmpty) {
      final suggestion = _lastSuggestions!.first;
      
      // Handle prayer time end times
      String? endTimeValue = updateFields['end_time']?.toString();
      if (endTimeValue != null) {
        // Check if it's a prayer name
        final prayerNames = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
        if (prayerNames.contains(endTimeValue.toLowerCase())) {
          // Get the actual prayer time
          final prayerKey = endTimeValue.substring(0, 1).toUpperCase() + endTimeValue.substring(1).toLowerCase();
          final prayerTimeStr = context.prayerTimes[prayerKey];
          if (prayerTimeStr != null) {
            endTimeValue = prayerTimeStr;
          }
        }
      }
      
      // Create a new updated suggestion
      final updatedSuggestion = TaskSuggestion(
        title: updateFields['title']?.toString() ?? suggestion.title,
        description: suggestion.description,
        scheduleType: suggestion.scheduleType,
        absoluteTime: updateFields['time']?.toString() ?? suggestion.absoluteTime,
        endTime: endTimeValue ?? suggestion.endTime, // Use converted prayer time or preserve existing
        relatedPrayer: suggestion.relatedPrayer,
        isBeforePrayer: suggestion.isBeforePrayer,
        minutesOffset: suggestion.minutesOffset,
        recurrenceType: updateFields['recurrence']?.toString() ?? suggestion.recurrenceType,
        priority: updateFields['priority'] != null 
            ? _parsePriority(updateFields['priority'].toString())
            : suggestion.priority,
        weeklyDays: suggestion.weeklyDays,
        endDate: suggestion.endDate,
        reasoningNotes: suggestion.reasoningNotes,
        energyLevel: suggestion.energyLevel,
      );
      
      // Check if anything actually changed
      bool hasChanges = false;
      String changesSummary = '';
      
      if (updateFields['title'] != null && updateFields['title'] != suggestion.title) {
        hasChanges = true;
        changesSummary += 'Renamed to "${updateFields['title']}"';
      }
      
      if (updateFields['priority'] != null) {
        final newPriority = _parsePriority(updateFields['priority'].toString());
        if (newPriority != suggestion.priority) {
          hasChanges = true;
          if (changesSummary.isNotEmpty) changesSummary += ', ';
          changesSummary += 'Priority set to ${newPriority.name}';
        }
      }
      
      if (updateFields['recurrence'] != null && updateFields['recurrence'] != suggestion.recurrenceType) {
        hasChanges = true;
        if (changesSummary.isNotEmpty) changesSummary += ', ';
        changesSummary += 'Changed to ${updateFields['recurrence']}';
      }
      
      if (updateFields['time'] != null && updateFields['time'] != suggestion.absoluteTime) {
        hasChanges = true;
        if (changesSummary.isNotEmpty) changesSummary += ', ';
        changesSummary += 'Time changed to ${updateFields['time']}';
      }
      
      if (updateFields['end_time'] != null && (endTimeValue != suggestion.endTime || updateFields['end_time'] != suggestion.endTime)) {
        hasChanges = true;
        if (changesSummary.isNotEmpty) changesSummary += ', ';
        // Check if it was a prayer name
        if (endTimeValue != updateFields['end_time']) {
          changesSummary += 'End time changed to ${updateFields['end_time']} prayer ($endTimeValue)';
        } else {
          changesSummary += 'End time changed to ${updateFields['end_time']}';
        }
      }
      
      if (!hasChanges) {
        return AIResponse(
          message: "The task already has those settings. Is there something else you'd like to change?",
          intent: ConversationIntent.taskUpdate,
          suggestions: [suggestion],
          needsConfirmation: false);
      }
      
      // Update the stored suggestions
      _lastSuggestions = [updatedSuggestion];
      
      // Return updated suggestion with specific changes
      return AIResponse(
        message: "I've updated the task. Changes: $changesSummary",
        intent: ConversationIntent.taskUpdate,
        suggestions: [updatedSuggestion],
        needsConfirmation: true,
        success: true);
    }
    
    // Look for the last task suggestion in conversation if no identifier
    if (identifier == null && context.todayTasks.isEmpty == false) {
      // If user says "make it high priority", they're likely referring to the last task discussed
      final lastTaskSuggestion = analysis.entities['last_task_reference'];
      if (lastTaskSuggestion != null) {
        identifier = lastTaskSuggestion;
      }
    }
    
    if (identifier == null && updateFields.isNotEmpty) {
      // User wants to update something but hasn't specified what
      return AIResponse(
        message: "Which task would you like me to update?",
        intent: ConversationIntent.taskUpdate,
        taskList: context.todayTasks.take(5).toList());
    }
    
    // Find matching task
    final matches = context.allTasks.where((t) =>
      t.task.title.toLowerCase().contains(identifier?.toString().toLowerCase() ?? '') ||
      (t.task.description?.toLowerCase().contains(identifier?.toString().toLowerCase() ?? '') ?? false)
    ).toList();
    
    if (matches.isEmpty) {
      return AIResponse(
        message: "I couldn't find a task to update. Could you be more specific?",
        intent: ConversationIntent.taskUpdate);
    }
    
    final taskToUpdate = matches.first;
    
    // Handle priority update
    if (updateFields['priority'] != null) {
      final newPriority = updateFields['priority'].toString().toLowerCase();
      TaskPriority priority;
      
      if (newPriority.contains('high') || newPriority.contains('more')) {
        priority = TaskPriority.high;
      } else if (newPriority.contains('low')) {
        priority = TaskPriority.low;
      } else {
        priority = TaskPriority.medium;
      }
      
      // Update the task
      final updatedTask = Task(
        id: taskToUpdate.task.id,
        title: taskToUpdate.task.title,
        description: taskToUpdate.task.description,
        priority: priority,
        createdAt: taskToUpdate.task.createdAt,
        scheduleType: taskToUpdate.task.scheduleType,
        absoluteTime: taskToUpdate.task.absoluteTime,
        relatedPrayer: taskToUpdate.task.relatedPrayer,
        isBeforePrayer: taskToUpdate.task.isBeforePrayer,
        minutesOffset: taskToUpdate.task.minutesOffset,
        recurrence: taskToUpdate.task.recurrence,
        completedDates: taskToUpdate.task.completedDates,
      );
      
      await TodoService.updateTask(updatedTask);
      
      return AIResponse(
        message: "✅ I've updated '${taskToUpdate.task.title}' to ${priority.name} priority.",
        intent: ConversationIntent.taskUpdate,
        success: true);
    }
    
    // Handle other updates in the future
    return AIResponse(
      message: "I've noted your update request. What would you like to change about '${taskToUpdate.task.title}'?",
      intent: ConversationIntent.taskUpdate);
  }
  
  static Future<AIResponse> _handleTaskComplete(
    ConversationAnalysis analysis,
    AIContext context) async {
    final identifier = analysis.entities['task_identifier'];
    
    if (identifier == null) {
      final incompleteTasks = context.todayTasks.where((t) => 
        !t.task.isCompletedToday()
      ).toList();
      
      if (incompleteTasks.isEmpty) {
        return AIResponse(
          message: "Great job! You've completed all your tasks for today! 🎉",
          intent: ConversationIntent.taskComplete,
          success: true);
      }
      
      return AIResponse(
        message: "Which task have you completed?",
        intent: ConversationIntent.taskComplete,
);
    }
    
    // Find and complete the task
    final matches = context.allTasks.where((t) =>
      t.task.title.toLowerCase().contains(identifier.toString().toLowerCase())
    ).toList();
    
    if (matches.isNotEmpty) {
      await TodoService.markTaskCompleted(matches.first.task.id, DateTime.now());
      return AIResponse(
        message: "✅ Excellent! I've marked '${matches.first.task.title}' as completed. Keep up the great work!",
        intent: ConversationIntent.taskComplete,
        success: true);
    }
    
    return AIResponse(
      message: "I couldn't find that task. Could you be more specific?",
      intent: ConversationIntent.taskComplete);
  }
  
  static Future<AIResponse> _handleTaskToSpace(
    ConversationAnalysis analysis,
    AIContext context) async {
    // Implementation for assigning task to space...
    return AIResponse(
      message: "Task to space assignment will be implemented",
      intent: ConversationIntent.taskToSpace);
  }
  
  static Future<AIResponse> _handleProductivityInsights(
    ConversationAnalysis analysis,
    AIContext context) async {
    // Generate personalized productivity insights
    final insights = StringBuffer("🌟 **Productivity Insights:**\n\n");
    
    // Best completion times
    final completedTasks = context.allTasks.where((t) => t.task.isCompletedToday()).toList();
    if (completedTasks.isNotEmpty) {
      insights.writeln("**Your Productive Hours:**");
      // Analysis logic here...
    }
    
    insights.writeln("\n**Tips for Better Productivity:**");
    insights.writeln("• Schedule important tasks after Fajr for clarity");
    insights.writeln("• Use time between Dhuhr and Asr for focused work");
    insights.writeln("• Keep evenings light after Maghrib");
    
    return AIResponse(
      message: insights.toString(),
      intent: ConversationIntent.productivity
    );
  }
  
  static Future<AIResponse> _handleFreeTimeQuery(
    ConversationAnalysis analysis,
    AIContext context) async {
    if (context.freeTimeSlots.isEmpty) {
      return AIResponse(
        message: "Your schedule is fully booked today! Consider moving some non-urgent tasks to tomorrow.",
        intent: ConversationIntent.freeTimeQuery
      );
    }
    
    final message = StringBuffer("Here are your free time slots today:\n\n");
    for (var slot in context.freeTimeSlots) {
      final startTime = DateFormat('h:mm a').format(slot.start);
      final endTime = DateFormat('h:mm a').format(slot.end);
      message.writeln("• $startTime - $endTime (${slot.durationMinutes} minutes) ${slot.label}");
    }
    
    message.writeln("\n💡 These are great times for focused work or personal activities!");
    
    return AIResponse(
      message: message.toString(),
      intent: ConversationIntent.freeTimeQuery,
      freeTimeSlots: context.freeTimeSlots
    );
  }
}

// Space suggestion model
class SpaceSuggestion {
  final String name;
  final String? description;
  final String color;
  final DateTime? dueDate;
  
  SpaceSuggestion({
    required this.name,
    this.description,
    required this.color,
    this.dueDate,
  });
}

// Updated response model
class AIResponse {
  final String message;
  final ConversationIntent intent;
  final List<TaskSuggestion>? suggestions;
  final List<SpaceSuggestion>? spaceSuggestions;
  final Map<String, dynamic>? extractedInfo;
  final List<String>? suggestedQuestions;
  final List<String>? quickActions;
  final bool needsConfirmation;
  final bool success;
  final List<TaskWithTime>? taskList;
  final List<Space>? spaceList;
  final Map<String, dynamic>? statistics;
  final List<TimeSlot>? freeTimeSlots;
  final String? error;
  
  AIResponse({
    required this.message,
    required this.intent,
    this.suggestions,
    this.spaceSuggestions,
    this.extractedInfo,
    this.suggestedQuestions,
    this.quickActions,
    this.needsConfirmation = false,
    this.success = false,
    this.taskList,
    this.spaceList,
    this.statistics,
    this.freeTimeSlots,
    this.error,
  });
}

// Updated analysis model
class ConversationAnalysis {
  final ConversationIntent intent;
  final double confidence;
  final Map<String, dynamic> entities;
  final List<String> missingInfo;
  final List<String> suggestions;
  
  ConversationAnalysis({
    required this.intent,
    required this.confidence,
    this.entities = const {},
    this.missingInfo = const [],
    this.suggestions = const [],
  });
}
