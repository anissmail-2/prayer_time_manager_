import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../models/task.dart';
import 'prayer_time_service.dart';
import 'prayer_duration_service.dart';
import 'todo_service.dart';
import '../config/config_loader.dart';

class GeminiTaskAssistant {
  static String get _apiKey => ConfigLoader.geminiApiKey;
  static const String _modelName = 'gemini-2.5-flash-lite-preview-06-17';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
  
  // Get task suggestions from Gemini
  static Future<List<TaskSuggestion>> getTaskSuggestions(String userInput) async {
    try {
      // Check if API key is available
      if (!ConfigLoader.hasValidGeminiKey) {
        print('Gemini API key not configured');
        return [];
      }
      
      // Generate context
      final context = await generateScheduleContext();
      final instructions = generateInstructions();
      
      // Build prompt
      final prompt = '''
$instructions

$context

USER REQUEST: $userInput

Please analyze the user's request and suggest appropriate tasks that fit into their schedule. Provide the response in the JSON format specified above.
''';

      // Call Gemini API
      final response = await http.post(
        Uri.parse('$_baseUrl/$_modelName:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{
            'parts': [{'text': prompt}]
          }]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String responseText = '';
        
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final content = data['candidates'][0]['content'];
          if (content != null && content['parts'] != null) {
            responseText = content['parts'][0]['text'] ?? '';
          }
        }
        
        return parseGeminiResponse(responseText);
      }
      
      return [];
    } catch (e) {
      // Error getting suggestions
      return [];
    }
  }
  
  // Generate context for Gemini about current schedule
  static Future<String> generateScheduleContext() async {
    final buffer = StringBuffer();
    final now = DateTime.now();
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    
    buffer.writeln('CURRENT SCHEDULE CONTEXT:');
    buffer.writeln('Today is ${dateFormat.format(now)}');
    buffer.writeln('Current time: ${DateFormat('h:mm a').format(now)}');
    buffer.writeln('');
    
    // Get prayer times and blocks
    final prayerTimes = await PrayerTimeService.getPrayerTimes();
    final prayerBlocks = await PrayerDurationService.getTodayPrayerBlocks();
    
    buffer.writeln('PRAYER SCHEDULE:');
    for (final block in prayerBlocks) {
      final prayerName = block.prayer.toString().split('.').last.toUpperCase();
      buffer.writeln('$prayerName:');
      buffer.writeln('  - Actual prayer time: ${DateFormat('h:mm a').format(block.actualPrayerTime)}');
      buffer.writeln('  - Your prayer block: ${DateFormat('h:mm a').format(block.startTime)} - ${DateFormat('h:mm a').format(block.endTime)}');
      buffer.writeln('  - Duration: ${block.duration.inMinutes} minutes');
    }
    buffer.writeln('');
    
    // Get existing tasks
    final tasks = await TodoService.getUpcomingTasksWithTimes(prayerTimes);
    
    if (tasks.isNotEmpty) {
      buffer.writeln('EXISTING TASKS TODAY:');
      for (final taskWithTime in tasks) {
        buffer.writeln('- ${taskWithTime.task.title} at ${DateFormat('h:mm a').format(taskWithTime.scheduledTime)}');
      }
      buffer.writeln('');
    }
    
    // Get free time slots
    final freeSlots = await PrayerDurationService.getFreeTimes(tasks);
    
    buffer.writeln('AVAILABLE FREE TIME SLOTS:');
    for (final slot in freeSlots) {
      final duration = slot.duration;
      buffer.writeln('- ${DateFormat('h:mm a').format(slot.startTime)} - ${DateFormat('h:mm a').format(slot.endTime)} (${duration.inHours}h ${duration.inMinutes % 60}m)');
    }
    
    return buffer.toString();
  }
  
  // Generate instructions for Gemini
  static String generateInstructions() {
    return '''
You are a personal task scheduling assistant for a Muslim prayer time management app. Your role is to help users create and schedule tasks around their prayer times.

SCHEDULING OPTIONS:
1. ABSOLUTE TIME: Schedule at a specific time (e.g., "3:00 PM")
2. PRAYER RELATIVE: Schedule before/after a prayer (e.g., "30 minutes before Maghrib")

RECURRENCE OPTIONS:
- ONCE: One-time task
- DAILY: Every day
- WEEKLY: Specific days of the week
- MONTHLY: Same day each month

AVAILABLE PRAYERS:
- Fajr (dawn prayer)
- Sunrise
- Dhuhr (noon prayer)
- Asr (afternoon prayer)
- Maghrib (sunset prayer)
- Isha (night prayer)

TASK CREATION FORMAT:
When suggesting tasks, provide them in this JSON format:
{
  "tasks": [
    {
      "title": "Task title",
      "description": "Optional description",
      "scheduleType": "absolute" or "prayerRelative",
      "absoluteTime": "HH:mm" (start time for absolute time),
      "endTime": "HH:mm" (optional end time for tasks with duration),
      "relatedPrayer": "fajr/sunrise/dhuhr/asr/maghrib/isha" (for prayer relative),
      "isBeforePrayer": true/false (for prayer relative),
      "minutesOffset": number (for prayer relative),
      "recurrenceType": "once/daily/weekly/monthly",
      "weeklyDays": [1,2,3,4,5,6,7] (1=Mon, 7=Sun, for weekly),
      "endDate": "YYYY-MM-DD" (optional)
    }
  ]
}

GUIDELINES:
1. Consider the user's prayer schedule and free time slots
2. Avoid scheduling during prayer blocks unless specifically requested
3. For religious activities, prefer scheduling after prayers
4. For work/study tasks, utilize longer free time slots
5. Be mindful of meal times (usually after Dhuhr and Maghrib)
6. Consider energy levels (morning for focus tasks, evening for relaxation)
7. IMPORTANT: When user specifies "from X to Y" or "X to Y", set absoluteTime to X and endTime to Y
8. If no end time is specified but duration is mentioned (e.g., "2 hour meeting"), calculate endTime
9. Do NOT assume a default 30-minute duration unless explicitly stated

When the user tells you about their life, goals, or routines, analyze their needs and suggest a comprehensive task schedule that fits around their prayer times.
''';
  }
  
  // Parse Gemini response to extract tasks
  static List<TaskSuggestion> parseGeminiResponse(String response) {
    final suggestions = <TaskSuggestion>[];
    
    try {
      // Extract JSON from response (Gemini might include explanation text)
      final jsonMatch = RegExp(r'\{[\s\S]*"tasks"[\s\S]*\}').firstMatch(response);
      if (jsonMatch == null) return suggestions;
      
      final jsonStr = jsonMatch.group(0)!;
      final json = jsonDecode(jsonStr);
      final tasks = json['tasks'] as List<dynamic>;
      
      for (final taskJson in tasks) {
        final suggestion = TaskSuggestion.fromJson(taskJson);
        suggestions.add(suggestion);
      }
    } catch (e) {
      // If parsing fails, return empty list
      // Error parsing Gemini response
    }
    
    return suggestions;
  }
  
  // Convert suggestions to actual tasks
  static Future<List<Task>> createTasksFromSuggestions(List<TaskSuggestion> suggestions) async {
    final tasks = <Task>[];
    final now = DateTime.now();
    
    for (final suggestion in suggestions) {
      DateTime? absoluteTime;
      
      if (suggestion.scheduleType == 'absolute' && suggestion.absoluteTime != null) {
        final parts = suggestion.absoluteTime!.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          if (hour != null && minute != null) {
            absoluteTime = DateTime(now.year, now.month, now.day, hour, minute);
          }
        }
      }
      
      final task = Task(
        id: DateTime.now().millisecondsSinceEpoch.toString() + tasks.length.toString(),
        title: suggestion.title,
        description: suggestion.description,
        createdAt: now,
        scheduleType: suggestion.scheduleType == 'prayerRelative' 
            ? ScheduleType.prayerRelative 
            : ScheduleType.absolute,
        absoluteTime: absoluteTime,
        relatedPrayer: suggestion.relatedPrayer != null 
            ? PrayerName.values.firstWhere(
                (p) => p.toString().split('.').last == suggestion.relatedPrayer,
                orElse: () => PrayerName.fajr,
              )
            : null,
        isBeforePrayer: suggestion.isBeforePrayer,
        minutesOffset: suggestion.minutesOffset,
        recurrence: _parseRecurrenceType(suggestion.recurrenceType),
        priority: suggestion.priority,
        weeklyDays: suggestion.weeklyDays,
        endDate: suggestion.endDate != null 
            ? DateTime.tryParse(suggestion.endDate!)
            : null,
      );
      
      tasks.add(task);
    }
    
    return tasks;
  }
  
  static TaskRecurrence _parseRecurrenceType(String? type) {
    switch (type?.toLowerCase()) {
      case 'daily':
        return TaskRecurrence.daily;
      case 'weekly':
        return TaskRecurrence.weekly;
      case 'monthly':
        return TaskRecurrence.monthly;
      default:
        return TaskRecurrence.once;
    }
  }
}

// Task suggestion model
class TaskSuggestion {
  String title;
  String? description;
  String scheduleType;
  String? absoluteTime;
  String? endTime; // New field for end time
  String? taskDate; // New field for task date (today/tomorrow/specific date)
  String? relatedPrayer;
  bool? isBeforePrayer;
  int? minutesOffset;
  String recurrenceType;
  List<int>? weeklyDays;
  String? endDate;
  TaskPriority priority;
  String? reasoningNotes;
  String? energyLevel;
  
  TaskSuggestion({
    required this.title,
    this.description,
    required this.scheduleType,
    this.absoluteTime,
    this.endTime, // New parameter
    this.taskDate, // New parameter
    this.relatedPrayer,
    this.isBeforePrayer,
    this.minutesOffset,
    required this.recurrenceType,
    this.weeklyDays,
    this.endDate,
    this.priority = TaskPriority.medium,
    this.reasoningNotes,
    this.energyLevel,
  });
  
  factory TaskSuggestion.fromJson(Map<String, dynamic> json) {
    return TaskSuggestion(
      title: json['title'],
      description: json['description'],
      scheduleType: json['scheduleType'] ?? 'absolute',
      absoluteTime: json['absoluteTime'],
      endTime: json['endTime'], // Parse end time
      taskDate: json['taskDate'], // Parse task date
      relatedPrayer: json['relatedPrayer'],
      isBeforePrayer: json['isBeforePrayer'],
      minutesOffset: json['minutesOffset'],
      recurrenceType: json['recurrenceType'] ?? 'once',
      weeklyDays: json['weeklyDays'] != null 
          ? List<int>.from(json['weeklyDays'])
          : null,
      endDate: json['endDate'],
      priority: _parsePriority(json['priority']),
      reasoningNotes: json['reasoningNotes'],
      energyLevel: json['energyLevel'],
    );
  }
  
  static TaskPriority _parsePriority(dynamic priority) {
    if (priority is int) {
      return TaskPriority.values[priority.clamp(0, TaskPriority.values.length - 1)];
    }
    switch (priority?.toString().toLowerCase()) {
      case 'high':
        return TaskPriority.high;
      case 'low':
        return TaskPriority.low;
      default:
        return TaskPriority.medium;
    }
  }
  
  String get schedulingInfo {
    if (scheduleType == 'absolute' && absoluteTime != null) {
      return 'At $absoluteTime';
    } else if (scheduleType == 'prayerRelative' && relatedPrayer != null) {
      final beforeAfter = isBeforePrayer == true ? 'before' : 'after';
      final offset = minutesOffset ?? 0;
      return '$offset min $beforeAfter $relatedPrayer';
    }
    return 'No specific time';
  }
}