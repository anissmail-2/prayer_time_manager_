import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/enhanced_ai_assistant.dart';
import '../../models/chat_message.dart';

class AIConversationService {
  static const String _conversationsKey = 'ai_conversations';
  static const String _currentConversationKey = 'current_ai_conversation';
  static const int _maxConversations = 10;

  /// Save the current conversation
  static Future<void> saveCurrentConversation(List<ChatMessage> messages) async {
    if (messages.isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    
    // Convert messages to JSON-serializable format
    final conversationData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      'title': _generateTitle(messages),
      'messageCount': messages.length,
      'messages': messages.map((msg) => _messageToJson(msg)).toList(),
    };
    
    // Save as current conversation
    await prefs.setString(_currentConversationKey, jsonEncode(conversationData));
    
    // Also add to conversation history
    await _addToHistory(conversationData);
  }

  /// Load the current conversation
  static Future<List<ChatMessage>> loadCurrentConversation() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_currentConversationKey);
    
    if (data == null) return [];
    
    try {
      final Map<String, dynamic> conversationData = jsonDecode(data);
      final List<dynamic> messagesJson = conversationData['messages'] ?? [];
      
      return messagesJson.map((json) => _messageFromJson(json)).toList();
    } catch (e) {
      // Error loading conversation
      return [];
    }
  }

  /// Get all saved conversations
  static Future<List<Map<String, dynamic>>> getAllConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_conversationsKey);
    
    if (data == null) return [];
    
    try {
      final List<dynamic> conversations = jsonDecode(data);
      return conversations.cast<Map<String, dynamic>>();
    } catch (e) {
      // Error loading conversations
      return [];
    }
  }

  /// Load a specific conversation by ID
  static Future<List<ChatMessage>> loadConversation(String conversationId) async {
    final conversations = await getAllConversations();
    
    final conversation = conversations.firstWhere(
      (conv) => conv['id'] == conversationId,
      orElse: () => {},
    );
    
    if (conversation.isEmpty) return [];
    
    final List<dynamic> messagesJson = conversation['messages'] ?? [];
    return messagesJson.map((json) => _messageFromJson(json)).toList();
  }

  /// Delete a conversation
  static Future<void> deleteConversation(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final conversations = await getAllConversations();
    
    conversations.removeWhere((conv) => conv['id'] == conversationId);
    
    await prefs.setString(_conversationsKey, jsonEncode(conversations));
  }

  /// Clear current conversation
  static Future<void> clearCurrentConversation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentConversationKey);
  }

  /// Clear all conversations
  static Future<void> clearAllConversations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_conversationsKey);
    await prefs.remove(_currentConversationKey);
  }

  // Helper methods
  
  static Future<void> _addToHistory(Map<String, dynamic> conversationData) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> conversations = await getAllConversations();
    
    // Add new conversation at the beginning
    conversations.insert(0, conversationData);
    
    // Keep only the most recent conversations
    if (conversations.length > _maxConversations) {
      conversations = conversations.take(_maxConversations).toList();
    }
    
    await prefs.setString(_conversationsKey, jsonEncode(conversations));
  }

  static String _generateTitle(List<ChatMessage> messages) {
    // Find the first user message for the title
    final firstUserMessage = messages.firstWhere(
      (msg) => msg.isUser,
      orElse: () => messages.first,
    );
    
    String title = firstUserMessage.text;
    if (title.length > 50) {
      title = '${title.substring(0, 47)}...';
    }
    
    return title;
  }

  static Map<String, dynamic> _messageToJson(ChatMessage message) {
    return {
      'text': message.text,
      'isUser': message.isUser,
      'timestamp': message.timestamp.toIso8601String(),
      'isError': message.isError,
      'isSuccess': message.isSuccess,
      'isSuggestionResponse': message.isSuggestionResponse,
      'isSpaceSuggestionResponse': message.isSpaceSuggestionResponse,
      'intent': message.intent?.toString(),
      'quickActions': message.quickActions,
      // Note: Complex objects like suggestions, taskList, etc. are not saved
      // to keep the storage lightweight. Only text conversation is preserved.
    };
  }

  static ChatMessage _messageFromJson(Map<String, dynamic> json) {
    ConversationIntent? intent;
    if (json['intent'] != null) {
      try {
        final intentStr = json['intent'].toString().split('.').last;
        intent = ConversationIntent.values.firstWhere(
          (e) => e.toString().split('.').last == intentStr,
          orElse: () => ConversationIntent.greeting,
        );
      } catch (e) {
        intent = null;
      }
    }

    return ChatMessage(
      text: json['text'] ?? '',
      isUser: json['isUser'] ?? false,
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      isError: json['isError'] ?? false,
      isSuccess: json['isSuccess'] ?? false,
      isSuggestionResponse: json['isSuggestionResponse'] ?? false,
      isSpaceSuggestionResponse: json['isSpaceSuggestionResponse'] ?? false,
      intent: intent,
      quickActions: (json['quickActions'] as List<dynamic>?)?.cast<String>(),
    );
  }
}