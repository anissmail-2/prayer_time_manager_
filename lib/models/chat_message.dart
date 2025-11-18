import '../core/services/gemini_task_assistant.dart';
import '../core/services/enhanced_ai_assistant.dart';
import '../core/services/todo_service.dart';
import '../models/space.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  final bool isSuccess;
  final bool isSuggestionResponse;
  final bool isSpaceSuggestionResponse;
  final List<TaskSuggestion>? suggestions;
  final List<SpaceSuggestion>? spaceSuggestions;
  final ConversationIntent? intent;
  final List<String>? quickActions;
  final List<TaskWithTime>? taskList;
  final List<Space>? spaceList;
  final Map<String, dynamic>? statistics;
  final List<TimeSlot>? freeTimeSlots;
  
  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    this.isSuccess = false,
    this.isSuggestionResponse = false,
    this.isSpaceSuggestionResponse = false,
    this.suggestions,
    this.spaceSuggestions,
    this.intent,
    this.quickActions,
    this.taskList,
    this.spaceList,
    this.statistics,
    this.freeTimeSlots,
  });
}