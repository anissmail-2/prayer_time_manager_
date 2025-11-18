import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../core/services/gemini_task_assistant.dart';
import '../core/services/enhanced_ai_assistant.dart';
import '../core/services/todo_service.dart';
import '../core/services/prayer_time_service.dart';
import '../core/services/space_service.dart';
import '../core/services/ai_conversation_service.dart';
import '../core/config/config_loader.dart';
import '../core/theme/app_theme.dart';
import '../core/helpers/permission_helper.dart';
import '../models/task.dart';
import '../models/space.dart';
import '../models/chat_message.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  List<TaskSuggestion> _pendingSuggestions = [];
  Map<String, String> _prayerTimes = {};
  bool _isLoading = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  String? _selectedFileName;
  
  static const platform = MethodChannel('com.awkati.taskflow/audio_recorder');
  static const filePickerPlatform = MethodChannel('com.awkati.taskflow/file_picker');
  
  // Deepgram configuration
  String _selectedModel = 'whisper-large';
  final Map<String, String> _modelDescriptions = {
    'nova-2': 'Nova 2 (Fastest)',
    'whisper-tiny': 'Whisper Tiny',
    'whisper-small': 'Whisper Small',
    'whisper-medium': 'Whisper Medium',
    'whisper-large': 'Whisper Large (Best)',
  };

  @override
  void initState() {
    super.initState();
    _loadPrayerTimes();
    _loadConversation();
    
    // Listen to text changes to update send button
    _messageController.addListener(() {
      setState(() {});
    });
  }

  Future<void> _loadPrayerTimes() async {
    try {
      _prayerTimes = await PrayerTimeService.getPrayerTimes();
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadConversation() async {
    final savedMessages = await AIConversationService.loadCurrentConversation();
    if (savedMessages.isNotEmpty) {
      setState(() {
        _messages.addAll(savedMessages);
      });
      _scrollToBottom();
    } else {
      _addWelcomeMessage();
    }
  }

  Future<void> _saveConversation() async {
    if (_messages.isNotEmpty) {
      await AIConversationService.saveCurrentConversation(_messages);
    }
  }

  @override
  void dispose() {
    _saveConversation();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(ChatMessage(
        text: 'Assalamu alaikum! How can I help you today?',
        isUser: false,
        timestamp: DateTime.now(),
        intent: ConversationIntent.greeting,
      ));
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    _messageController.clear();
    
    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      // Use enhanced AI assistant for more intelligent responses
      final aiResponse = await EnhancedAIAssistant.processMessage(message, _messages);
      
      // Add AI response to chat
      setState(() {
        _messages.add(ChatMessage(
          text: aiResponse.message,
          isUser: false,
          timestamp: DateTime.now(),
          intent: aiResponse.intent,
          quickActions: aiResponse.quickActions ?? aiResponse.suggestedQuestions,
          taskList: aiResponse.taskList,
          spaceList: aiResponse.spaceList,
          statistics: aiResponse.statistics,
          freeTimeSlots: aiResponse.freeTimeSlots,
          isSuccess: aiResponse.success,
        ));
      });
      
      // If AI has task suggestions ready, show them after a brief delay
      if (aiResponse.suggestions != null && aiResponse.suggestions!.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
        
        final enhancedSuggestions = await _enhanceSuggestionsWithTimes(aiResponse.suggestions!);
        
        setState(() {
          _pendingSuggestions = enhancedSuggestions;
          // Update the last message to include suggestions instead of adding a new one
          if (_messages.isNotEmpty && _messages.last == _messages[_messages.length - 1]) {
            _messages[_messages.length - 1] = ChatMessage(
              text: _messages.last.text,
              isUser: false,
              timestamp: _messages.last.timestamp,
              intent: _messages.last.intent,
              quickActions: _messages.last.quickActions,
              taskList: _messages.last.taskList,
              spaceList: _messages.last.spaceList,
              statistics: _messages.last.statistics,
              freeTimeSlots: _messages.last.freeTimeSlots,
              isSuccess: _messages.last.isSuccess,
              suggestions: enhancedSuggestions,
              isSuggestionResponse: true,
            );
          }
        });
      }
      
      // If AI has space suggestions ready, show them
      if (aiResponse.spaceSuggestions != null && aiResponse.spaceSuggestions!.isNotEmpty) {
        await Future.delayed(const Duration(seconds: 1));
        
        setState(() {
          _messages.add(ChatMessage(
            text: '',  // Empty text since the suggestion card shows all details
            isUser: false,
            timestamp: DateTime.now(),
            spaceSuggestions: aiResponse.spaceSuggestions,
            isSpaceSuggestionResponse: true,
          ));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'I apologize, but I\'m having trouble processing your request. Could you please try again?',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
      _saveConversation();
    }
  }

  Future<List<TaskSuggestion>> _enhanceSuggestionsWithTimes(List<TaskSuggestion> suggestions) async {
    // Calculate exact times for each suggestion
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    for (final suggestion in suggestions) {
      if (suggestion.scheduleType == 'absolute' && suggestion.absoluteTime != null) {
        // Already has absolute time
      } else if (suggestion.scheduleType == 'prayerRelative' && 
                 suggestion.relatedPrayer != null && 
                 _prayerTimes.isNotEmpty) {
        // Calculate prayer relative time
        final prayerKey = suggestion.relatedPrayer!.substring(0, 1).toUpperCase() + 
                         suggestion.relatedPrayer!.substring(1);
        final prayerTimeStr = _prayerTimes[prayerKey];
        
        if (prayerTimeStr != null) {
          final parts = prayerTimeStr.split(':');
          if (parts.length == 2) {
            final hour = int.tryParse(parts[0]);
            final minute = int.tryParse(parts[1]);
            
            if (hour != null && minute != null) {
              var prayerTime = DateTime(today.year, today.month, today.day, hour, minute);
              final offset = suggestion.minutesOffset ?? 0;
              
              if (suggestion.isBeforePrayer == true) {
                prayerTime = prayerTime.subtract(Duration(minutes: offset));
              } else {
                prayerTime = prayerTime.add(Duration(minutes: offset));
              }
              
              // Store the calculated time in absoluteTime for display
              suggestion.calculatedTime = DateFormat('h:mm a').format(prayerTime);
            }
          }
        }
      }
    }
    
    return suggestions;
  }

  Future<void> _acceptSuggestion(TaskSuggestion suggestion) async {
    try {
      await TodoService.createTaskFromSuggestion(suggestion);
      
      setState(() {
        _pendingSuggestions.remove(suggestion);
        _messages.add(ChatMessage(
          text: '✅ Task "${suggestion.title}" has been added to your schedule!',
          isUser: false,
          timestamp: DateTime.now(),
          isSuccess: true,
        ));
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Task added: ${suggestion.title}')),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height * 0.1,
              left: 16,
              right: 16,
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding task: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectSuggestion(TaskSuggestion suggestion) async {
    setState(() {
      _pendingSuggestions.remove(suggestion);
    });
  }

  Future<void> _acceptSpaceSuggestion(SpaceSuggestion suggestion) async {
    try {
      final space = Space(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: suggestion.name,
        description: suggestion.description,
        color: suggestion.color,
        createdAt: DateTime.now(),
      );
      
      await SpaceService.createSpace(space);
      
      // Update the AI assistant context with the created space
      EnhancedAIAssistant.updateLastCreatedSpace(space.id, space.name);
      
      setState(() {
        _messages.add(ChatMessage(
          text: '✅ Space "${suggestion.name}" has been created successfully!',
          isUser: false,
          timestamp: DateTime.now(),
          isSuccess: true,
        ));
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Space created: ${suggestion.name}')),
              ],
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating space: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectSpaceSuggestion(SpaceSuggestion suggestion) async {
    setState(() {
      // Remove the space suggestion message
      _messages.removeWhere((msg) => 
        msg.spaceSuggestions?.contains(suggestion) ?? false
      );
    });
  }

  Future<void> _startRecording() async {
    if (Theme.of(context).platform != TargetPlatform.android) {
      _pickAudioFile();
      return;
    }

    try {
      await platform.invokeMethod('startRecording');
      setState(() {
        _isRecording = true;
      });
    } on PlatformException catch (e) {
      setState(() {
        _isRecording = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start recording: ${e.message}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      setState(() {
        _isRecording = false;
        _isTranscribing = true;
      });
      
      final Map<dynamic, dynamic> result = await platform.invokeMethod('stopRecording');
      final String? path = result['path'];
      final int? size = result['size'];
      
      if (path != null) {
        await _transcribeFile(path);
      }
    } on PlatformException catch (e) {
      setState(() {
        _isRecording = false;
        _isTranscribing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop recording: ${e.message}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _pickAudioFile() async {
    // First try the native method channel for Android to get proper file picker
    if (Platform.isAndroid) {
      try {
        // Check storage permissions first
        final hasPermission = await PermissionHelper.hasGalleryPermission();
        if (!hasPermission) {
          await PermissionHelper.requestAllPermissions();
        }
        
        // Use native method channel to show system file picker with all sources
        final Map<dynamic, dynamic> result = await filePickerPlatform.invokeMethod('pickAudioFile');
        final String? path = result['path'];
        final String? name = result['name'];
        
        if (path != null) {
          setState(() {
            _selectedFileName = name ?? 'Audio file';
            _isTranscribing = true;
          });
          await _transcribeFile(path);
          return;
        }
      } catch (e) {
        // If native method fails, fall back to file_picker package
        print('Native file picker failed: $e');
      }
    }
    
    // Fallback to file_picker package for iOS or if native method fails
    try {
      FilePickerResult? result;
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.audio,
          allowMultiple: false,
        );
      } catch (e) {
        // If audio picker fails, fall back to any
        result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: false,
        );
      }

      if (result != null && result.files.single.path != null) {
        // Check if it's an audio file
        final extension = result.files.single.extension?.toLowerCase() ?? '';
        final audioExtensions = [
          'mp3', 'mp4', 'm4a', 'wav', 'ogg', 'aac', 'opus', 'flac', 
          'webm', 'amr', '3gp', 'aiff', 'wma', 'mpeg', 'mpga'
        ];
        
        if (audioExtensions.contains(extension) || 
            result.files.single.name.toLowerCase().contains('.mp') ||
            result.files.single.name.toLowerCase().contains('.wav') ||
            result.files.single.name.toLowerCase().contains('.m4a')) {
          setState(() {
            _selectedFileName = result!.files.single.name;
            _isTranscribing = true;
          });
          await _transcribeFile(result.files.single.path!);
        } else {
          if (mounted) {
            // Ask if they want to proceed anyway
            final proceed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Non-audio file selected'),
                content: Text('The selected file (.$extension) may not be an audio file. Do you want to try transcribing it anyway?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Try Anyway'),
                  ),
                ],
              ),
            );
            
            if (proceed == true) {
              setState(() {
                _selectedFileName = result!.files.single.name;
                _isTranscribing = true;
              });
              await _transcribeFile(result.files.single.path!);
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _transcribeFile(String filePath) async {
    setState(() {
      _isTranscribing = true;
    });
    
    try {
      // Check if Deepgram API key is available
      if (!ConfigLoader.hasValidDeepgramKey) {
        throw Exception('Voice transcription is not configured. Please check your API key settings.');
      }
      
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      
      final response = await http.post(
        Uri.parse('https://api.deepgram.com/v1/listen?model=$_selectedModel&punctuate=true&language=en-US'),
        headers: {
          'Authorization': 'Token ${ConfigLoader.deepgramApiKey}',
          'Content-Type': 'audio/mp4',
        },
        body: bytes,
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        String transcript = '';
        
        try {
          if (json['results']?['channels']?.isNotEmpty ?? false) {
            final channel = json['results']['channels'][0];
            if (channel['alternatives']?.isNotEmpty ?? false) {
              transcript = channel['alternatives'][0]['transcript'] ?? '';
            }
          }
        } catch (e) {
          transcript = 'Error parsing response';
        }
        
        setState(() {
          _messageController.text = transcript.isEmpty ? 'No speech detected' : transcript;
          _isTranscribing = false;
          _selectedFileName = null;
        });
        
        if (mounted && transcript.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transcription complete!'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } else {
        setState(() {
          _isTranscribing = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('API Error: ${response.statusCode}'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isTranscribing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppTheme.animationMedium,
          curve: AppTheme.animationCurve,
        );
      }
    });
  }

  String _formatChatForCopy() {
    final buffer = StringBuffer();
    buffer.writeln('AI Assistant Chat - ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.now())}');
    buffer.writeln('=' * 50);
    buffer.writeln();

    for (final message in _messages) {
      // Header
      final role = message.isUser ? 'You' : 'AI Assistant';
      final time = DateFormat('h:mm a').format(message.timestamp);
      buffer.writeln('[$time] $role:');
      buffer.writeln(message.text);

      // Add task suggestions if present
      if (message.suggestions != null && message.suggestions!.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('Task Suggestions:');
        for (var i = 0; i < message.suggestions!.length; i++) {
          final suggestion = message.suggestions![i];
          buffer.writeln('  ${i + 1}. ${suggestion.title}');
          if (suggestion.description != null && suggestion.description!.isNotEmpty) {
            buffer.writeln('     ${suggestion.description}');
          }
          final timeDisplay = suggestion.endTime != null 
              ? '${suggestion.calculatedTime ?? suggestion.absoluteTime} - ${suggestion.endTime}'
              : (suggestion.calculatedTime ?? suggestion.absoluteTime ?? suggestion.schedulingInfo);
          buffer.writeln('     Time: $timeDisplay');
          buffer.writeln('     Priority: ${suggestion.priority.name}');
        }
      }

      // Add task list if present
      if (message.taskList != null && message.taskList!.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('Tasks (${message.taskList!.length}):');
        for (var i = 0; i < message.taskList!.length && i < 5; i++) {
          final taskWithTime = message.taskList![i];
          final status = taskWithTime.task.isCompletedToday() ? '[✓]' : '[ ]';
          buffer.writeln('  $status ${taskWithTime.task.title}');
          buffer.writeln('      ${taskWithTime.task.getDisplayTimeString(_prayerTimes)}');
        }
        if (message.taskList!.length > 5) {
          buffer.writeln('  ... and ${message.taskList!.length - 5} more');
        }
      }

      // Add space list if present
      if (message.spaceList != null && message.spaceList!.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('Spaces:');
        for (final space in message.spaceList!) {
          buffer.writeln('  - ${space.name}');
          if (message.statistics?[space.id] != null) {
            final stats = message.statistics![space.id];
            buffer.writeln('    ${stats['pending']} pending, ${stats['completed']} completed');
          }
        }
      }

      // Add free time slots if present
      if (message.freeTimeSlots != null && message.freeTimeSlots!.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('Free Time Slots:');
        for (final slot in message.freeTimeSlots!) {
          buffer.writeln('  - ${DateFormat('h:mm a').format(slot.start)} - ${DateFormat('h:mm a').format(slot.end)}');
          buffer.writeln('    ${slot.durationMinutes} minutes ${slot.label}');
        }
      }

      // Add statistics if present
      if (message.statistics != null && message.spaceList == null && message.statistics!.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('Statistics: ${_formatStatistics(message.statistics!)}');
      }

      buffer.writeln();
      buffer.writeln('-' * 30);
      buffer.writeln();
    }

    return buffer.toString();
  }

  Future<void> _copyChat() async {
    final chatContent = _formatChatForCopy();
    await Clipboard.setData(ClipboardData(text: chatContent));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Chat copied to clipboard'),
            ],
          ),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.1,
            left: 16,
            right: 16,
          ),
        ),
      );
    }
  }

  Future<void> _handleConversationMenu(String value) async {
    switch (value) {
      case 'new':
        _startNewConversation();
        break;
      case 'history':
        _showConversationHistory();
        break;
      case 'clear':
        _confirmClearConversation();
        break;
    }
  }

  void _startNewConversation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Conversation'),
        content: const Text('Save current conversation and start a new one?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _saveConversation();
              await AIConversationService.clearCurrentConversation();
              setState(() {
                _messages.clear();
                _pendingSuggestions.clear();
              });
              _addWelcomeMessage();
            },
            child: const Text('Start New'),
          ),
        ],
      ),
    );
  }

  void _showConversationHistory() async {
    final conversations = await AIConversationService.getAllConversations();
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.space16),
              child: Row(
                children: [
                  const Icon(Icons.history, color: AppTheme.primary),
                  const SizedBox(width: AppTheme.space8),
                  Text(
                    'Conversation History',
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (conversations.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await AIConversationService.clearAllConversations();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('All conversations cleared'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: const Text('Clear All'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: conversations.isEmpty
                  ? Center(
                      child: Text(
                        'No saved conversations',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final conv = conversations[index];
                        final timestamp = DateTime.parse(conv['timestamp']);
                        return Card(
                          margin: const EdgeInsets.only(bottom: AppTheme.space8),
                          child: ListTile(
                            title: Text(
                              conv['title'] ?? 'Untitled Conversation',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${DateFormat('MMM d, h:mm a').format(timestamp)} • ${conv['messageCount']} messages',
                              style: AppTheme.labelSmall,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () async {
                                await AIConversationService.deleteConversation(conv['id']);
                                Navigator.pop(context);
                                _showConversationHistory();
                              },
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              // Save current conversation first
                              await _saveConversation();
                              // Load selected conversation
                              final messages = await AIConversationService.loadConversation(conv['id']);
                              setState(() {
                                _messages.clear();
                                _messages.addAll(messages);
                                _pendingSuggestions.clear();
                              });
                              _scrollToBottom();
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearConversation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Conversation'),
        content: const Text('Are you sure you want to clear the current conversation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AIConversationService.clearCurrentConversation();
              setState(() {
                _messages.clear();
                _pendingSuggestions.clear();
              });
              _addWelcomeMessage();
            },
            child: const Text('Clear', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
  
  IconData _getIntentIcon(ConversationIntent? intent) {
    switch (intent) {
      case ConversationIntent.taskCreation:
        return Icons.add_task;
      case ConversationIntent.taskDeletion:
        return Icons.delete_outline;
      case ConversationIntent.taskUpdate:
        return Icons.edit;
      case ConversationIntent.taskView:
        return Icons.list_alt;
      case ConversationIntent.taskComplete:
        return Icons.check_circle_outline;
      case ConversationIntent.scheduling:
        return Icons.schedule;
      case ConversationIntent.planning:
        return Icons.calendar_today;
      case ConversationIntent.greeting:
        return Icons.waving_hand;
      case ConversationIntent.clarification:
        return Icons.help_outline;
      case ConversationIntent.confirmation:
        return Icons.thumb_up;
      case ConversationIntent.command:
        return Icons.terminal;
      default:
        return Icons.auto_awesome;
    }
  }
  
  // Handle quick action buttons
  Future<void> _handleQuickAction(String action) async {
    _messageController.text = action;
    await _sendMessage();
  }
  
  // The enhanced AI assistant now handles all operations directly
  // These old methods are no longer needed as the AI executes everything
  
  Future<void> _showTaskStats() async {
    // This is kept only for backward compatibility
    // The AI now provides statistics directly
    _messageController.text = "Show me my task statistics";
    await _sendMessage();
  }
  
  // Placeholder for any legacy code that might call this
  Future<void> _showTasks(String scope) async {
    _messageController.text = "Show me my $scope tasks";
    await _sendMessage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildCompactHeader(),
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.only(
                        left: AppTheme.space16,
                        right: AppTheme.space16,
                        top: AppTheme.space8,
                        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.space64,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) => _buildMessage(_messages[index]),
                    ),
            ),
            if (_selectedFileName != null) _buildSelectedFileIndicator(),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderLight,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.space8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.secondary, AppTheme.secondaryDark],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Text(
              'AI Assistant',
              style: AppTheme.titleMedium.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Quick actions in a row
          if (_messages.isNotEmpty)
            IconButton(
              onPressed: _copyChat,
              icon: const Icon(Icons.copy, size: 20),
              color: AppTheme.textSecondary,
              tooltip: 'Copy chat',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
            ),
          // Conversation menu
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 20, color: AppTheme.textSecondary),
            tooltip: 'Conversation options',
            onSelected: _handleConversationMenu,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'new',
                child: Row(
                  children: [
                    Icon(Icons.add_comment, size: 18),
                    SizedBox(width: 8),
                    Text('New conversation'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history, size: 18),
                    SizedBox(width: 8),
                    Text('Conversation history'),
                  ],
                ),
              ),
              if (_messages.isNotEmpty)
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.clear, size: 18),
                      SizedBox(width: 8),
                      Text('Clear conversation'),
                    ],
                  ),
                ),
            ],
          ),
          // Model selector as icon button
          IconButton(
            onPressed: () => _showModelSelector(context),
            icon: Icon(Icons.mic, size: 20, color: AppTheme.textSecondary),
            tooltip: 'Voice model: $_selectedModel',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showModelSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
              child: Text(
                'Select Voice Model',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space16),
            ..._modelDescriptions.entries.map((entry) => ListTile(
              leading: Radio<String>(
                value: entry.key,
                groupValue: _selectedModel,
                onChanged: (value) {
                  setState(() => _selectedModel = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text(entry.key),
              subtitle: Text(
                entry.value,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              onTap: () {
                setState(() => _selectedModel = entry.key);
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.secondary.withOpacity(0.1),
                    AppTheme.secondaryDark.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 40,
                color: AppTheme.secondary,
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            Text(
              'How can I help you today?',
              style: AppTheme.titleLarge.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            Text(
              'I can help you manage tasks, create spaces,\nand optimize your schedule',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.space32),
            Column(
              children: [
                _buildQuickStartSection(
                  'Get Started',
                  [
                    _buildQuickAction(Icons.task_alt, 'Show my tasks for today'),
                    _buildQuickAction(Icons.add_task, 'Create a new task'),
                    _buildQuickAction(Icons.folder, 'Show all spaces'),
                    _buildQuickAction(Icons.free_breakfast, 'Find free time slots'),
                  ],
                ),
                const SizedBox(height: AppTheme.space16),
                _buildQuickStartSection(
                  'Popular Requests',
                  [
                    _buildQuickAction(Icons.school, 'Help me study for exams'),
                    _buildQuickAction(Icons.work, 'Plan a productive workday'),
                    _buildQuickAction(Icons.fitness_center, 'Create a fitness routine'),
                    _buildQuickAction(Icons.analytics, 'Show my task statistics'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuickStartSection(String title, List<Widget> actions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.labelMedium.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        Wrap(
          spacing: AppTheme.space8,
          runSpacing: AppTheme.space8,
          children: actions,
        ),
      ],
    );
  }
  
  Widget _buildQuickAction(IconData icon, String text) {
    return InkWell(
      onTap: () {
        _messageController.text = text;
        _sendMessage();
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space12,
          vertical: AppTheme.space8,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(
            color: AppTheme.borderLight,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: AppTheme.space8),
            Text(
              text,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        _messageController.text = text;
        _sendMessage();
      },
      backgroundColor: AppTheme.surfaceVariant,
      labelStyle: AppTheme.bodyMedium.copyWith(
        color: AppTheme.textPrimary,
      ),
    );
  }
  
  Widget _buildCompactTaskItem(TaskWithTime taskWithTime) {
    final isCompleted = taskWithTime.task.isCompletedToday();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space12,
        vertical: AppTheme.space8,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderLight.withOpacity(0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isCompleted ? AppTheme.success : AppTheme.borderLight,
                width: 2,
              ),
              color: isCompleted ? AppTheme.success : Colors.transparent,
            ),
            child: isCompleted
                ? const Icon(
                    Icons.check,
                    size: 12,
                    color: Colors.white,
                  )
                : null,
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  taskWithTime.task.title,
                  style: AppTheme.bodySmall.copyWith(
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted ? AppTheme.textSecondary : AppTheme.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  taskWithTime.task.getDisplayTimeString(_prayerTimes),
                  style: AppTheme.labelSmall.copyWith(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getPriorityColor(taskWithTime.task.priority),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompactSpaceItem(Space space, Map<String, dynamic>? stats) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space12,
        vertical: AppTheme.space12,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderLight.withOpacity(0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getSpaceColor(space.color ?? 'blue').withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.folder,
              color: _getSpaceColor(space.color ?? 'blue'),
              size: 18,
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  space.name,
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                if (stats != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${stats['pending']} pending, ${stats['completed']} completed',
                    style: AppTheme.labelSmall.copyWith(
                      color: AppTheme.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompactTimeSlot(TimeSlot slot) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space12,
        vertical: AppTheme.space8,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateFormat('h:mm a').format(slot.start)} - ${DateFormat('h:mm a').format(slot.end)}',
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 12,
                      color: AppTheme.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${slot.durationMinutes} minutes',
                      style: AppTheme.labelSmall.copyWith(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                    if (slot.label.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• ${slot.label}',
                        style: AppTheme.labelSmall.copyWith(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.space12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: message.isError
                    ? AppTheme.error.withOpacity(0.1)
                    : message.isSuccess
                        ? AppTheme.success.withOpacity(0.1)
                        : message.isSuggestionResponse
                            ? AppTheme.info.withOpacity(0.1)
                            : message.isSpaceSuggestionResponse
                                ? AppTheme.primary.withOpacity(0.1)
                                : AppTheme.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                message.isError
                    ? Icons.error_outline
                    : message.isSuccess
                        ? Icons.check
                        : message.isSuggestionResponse
                            ? Icons.task_alt
                            : message.isSpaceSuggestionResponse
                                ? Icons.folder_special
                                : _getIntentIcon(message.intent),
                color: message.isError
                    ? AppTheme.error
                    : message.isSuccess
                        ? AppTheme.success
                        : message.isSuggestionResponse
                            ? AppTheme.info
                            : message.isSpaceSuggestionResponse
                                ? AppTheme.primary
                                : AppTheme.secondary,
                size: 18,
              ),
            ),
            const SizedBox(width: AppTheme.space8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space12,
                    vertical: AppTheme.space12,
                  ),
                  decoration: BoxDecoration(
                    color: message.isUser
                        ? AppTheme.primary
                        : message.isError
                            ? AppTheme.error.withOpacity(0.1)
                            : message.isSuccess
                                ? AppTheme.success.withOpacity(0.1)
                                : message.isSuggestionResponse
                                    ? Colors.transparent
                                    : AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(message.isUser ? AppTheme.radiusMedium : AppTheme.space4),
                      topRight: Radius.circular(message.isUser ? AppTheme.space4 : AppTheme.radiusMedium),
                      bottomLeft: const Radius.circular(AppTheme.radiusMedium),
                      bottomRight: const Radius.circular(AppTheme.radiusMedium),
                    ),
                    border: message.isSuggestionResponse || message.isSpaceSuggestionResponse
                        ? null
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.text.isNotEmpty)
                        SelectableText(
                          message.text,
                          style: AppTheme.bodyMedium.copyWith(
                            color: message.isUser
                                ? Colors.white
                                : message.isError
                                    ? AppTheme.error
                                    : message.isSuccess
                                        ? AppTheme.success
                                        : AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      // Display task list if present
                      if (message.taskList != null && message.taskList!.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.space12),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            border: Border.all(color: AppTheme.borderLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.space12,
                                  vertical: AppTheme.space8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.task_alt,
                                      size: 16,
                                      color: AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: AppTheme.space8),
                                    Text(
                                      'Tasks (${message.taskList!.length})',
                                      style: AppTheme.labelMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              ...message.taskList!.take(5).map((taskWithTime) => 
                                _buildCompactTaskItem(taskWithTime)
                              ),
                              if (message.taskList!.length > 5)
                                Padding(
                                  padding: const EdgeInsets.all(AppTheme.space12),
                                  child: Text(
                                    '... and ${message.taskList!.length - 5} more',
                                    style: AppTheme.labelSmall.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      // Display space list if present
                      if (message.spaceList != null && message.spaceList!.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.space12),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            border: Border.all(color: AppTheme.borderLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.space12,
                                  vertical: AppTheme.space8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.folder_special,
                                      size: 16,
                                      color: AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: AppTheme.space8),
                                    Text(
                                      'Spaces',
                                      style: AppTheme.labelMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              ...message.spaceList!.map((space) => 
                                _buildCompactSpaceItem(space, message.statistics?[space.id])
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Display free time slots if present
                      if (message.freeTimeSlots != null && message.freeTimeSlots!.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.space12),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.success.withOpacity(0.05),
                                AppTheme.success.withOpacity(0.02),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            border: Border.all(color: AppTheme.success.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.space12,
                                  vertical: AppTheme.space8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.schedule_outlined,
                                      size: 16,
                                      color: AppTheme.success,
                                    ),
                                    const SizedBox(width: AppTheme.space8),
                                    Text(
                                      'Free Time Available',
                                      style: AppTheme.labelMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, color: Colors.transparent),
                              ...message.freeTimeSlots!.take(4).map((slot) => 
                                _buildCompactTimeSlot(slot)
                              ),
                              if (message.freeTimeSlots!.length > 4)
                                Padding(
                                  padding: const EdgeInsets.all(AppTheme.space12),
                                  child: Text(
                                    '... and ${message.freeTimeSlots!.length - 4} more slots',
                                    style: AppTheme.labelSmall.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      // Display statistics if present
                      if (message.statistics != null && 
                          message.spaceList == null && // Don't show general stats if already showing space stats
                          message.statistics!.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.space16),
                        Container(
                          padding: const EdgeInsets.all(AppTheme.space12),
                          decoration: BoxDecoration(
                            color: AppTheme.info.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            border: Border.all(color: AppTheme.info.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.analytics,
                                color: AppTheme.info,
                                size: 20,
                              ),
                              const SizedBox(width: AppTheme.space8),
                              Expanded(
                                child: Text(
                                  _formatStatistics(message.statistics!),
                                  style: AppTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (message.suggestions != null && message.suggestions!.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.space16),
                        ...message.suggestions!.map((suggestion) => _buildSuggestionCard(suggestion)),
                      ],
                      if (message.spaceSuggestions != null && message.spaceSuggestions!.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.space16),
                        ...message.spaceSuggestions!.map((suggestion) => _buildSpaceSuggestionCard(suggestion)),
                      ],
                    ],
                  ),
                ),
                if (!message.isSuggestionResponse && !message.isSpaceSuggestionResponse)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTheme.space4),
                    child: Text(
                      DateFormat('h:mm a').format(message.timestamp),
                      style: AppTheme.labelSmall.copyWith(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: AppTheme.space8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.person,
                color: AppTheme.primary,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(TaskSuggestion suggestion) {
    return EditableTaskSuggestionCard(
      suggestion: suggestion,
      onAccept: _acceptSuggestion,
      onReject: _rejectSuggestion,
    );
  }

  Widget _buildSpaceSuggestionCard(SpaceSuggestion suggestion) {
    return EditableSpaceSuggestionCard(
      suggestion: suggestion,
      onAccept: _acceptSpaceSuggestion,
      onReject: _rejectSpaceSuggestion,
    );
  }

  Widget _buildSelectedFileIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.info.withOpacity(0.1),
        border: Border(
          top: BorderSide(color: AppTheme.borderLight),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.audio_file, color: AppTheme.info, size: 20),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: Text(
              _selectedFileName!,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.info),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _selectedFileName = null),
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: AppTheme.space12,
        right: AppTheme.space12,
        top: AppTheme.space8,
        bottom: AppTheme.space8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(
            color: AppTheme.borderLight,
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Compact actions in input field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // File picker button inside field
                  if (!_isRecording)
                    IconButton(
                      onPressed: _isTranscribing ? null : _pickAudioFile,
                      icon: const Icon(Icons.attach_file, size: 20),
                      color: AppTheme.textSecondary,
                      tooltip: 'Attach file',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  // Input field
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: 4,
                      minLines: 1,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      enableInteractiveSelection: true,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ask me anything...',
                        hintStyle: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space4,
                          vertical: AppTheme.space12,
                        ),
                      ),
                    ),
                  ),
                  // Microphone button inside field
                  if (!_isRecording && !_isTranscribing)
                    IconButton(
                      onPressed: _startRecording,
                      icon: const Icon(Icons.mic, size: 20),
                      color: AppTheme.textSecondary,
                      tooltip: 'Voice input',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space8),
          // Action button
          if (_isRecording)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.error,
              ),
              child: IconButton(
                onPressed: _stopRecording,
                icon: const Icon(Icons.stop, size: 18),
                color: Colors.white,
                padding: EdgeInsets.zero,
              ),
            )
          else if (_isTranscribing)
            Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(AppTheme.space12),
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _messageController.text.trim().isEmpty
                    ? AppTheme.borderLight
                    : AppTheme.primary,
              ),
              child: IconButton(
                onPressed: _messageController.text.trim().isEmpty || _isLoading
                    ? null 
                    : _sendMessage,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        Icons.send, 
                        size: 18,
                        color: _messageController.text.trim().isEmpty
                            ? AppTheme.textSecondary
                            : Colors.white,
                      ),
                padding: EdgeInsets.zero,
              ),
            ),
        ],
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
  
  Widget _getPriorityIcon(TaskPriority priority) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _getPriorityColor(priority).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.flag,
        size: 16,
        color: _getPriorityColor(priority),
      ),
    );
  }
  
  Color _getSpaceColor(String colorName) {
    final colors = {
      'blue': Colors.blue,
      'green': Colors.green,
      'purple': Colors.purple,
      'orange': Colors.orange,
      'pink': Colors.pink,
      'teal': Colors.teal,
      'red': Colors.red,
      'indigo': Colors.indigo,
    };
    return colors[colorName] ?? Colors.blue;
  }
  
  String _formatStatistics(Map<String, dynamic> stats) {
    final parts = <String>[];
    if (stats['total'] != null) parts.add('Total: ${stats['total']}');
    if (stats['completed'] != null) parts.add('Completed: ${stats['completed']}');
    if (stats['high_priority'] != null) parts.add('High Priority: ${stats['high_priority']}');
    return parts.join(' • ');
  }
}

// Extension to add calculated time to TaskSuggestion
extension TaskSuggestionExtension on TaskSuggestion {
  static final Map<TaskSuggestion, String> _calculatedTimes = {};
  
  String? get calculatedTime => _calculatedTimes[this];
  
  set calculatedTime(String? time) {
    if (time != null) {
      _calculatedTimes[this] = time;
    } else {
      _calculatedTimes.remove(this);
    }
  }
}

// Editable Task Suggestion Card
class EditableTaskSuggestionCard extends StatefulWidget {
  final TaskSuggestion suggestion;
  final Function(TaskSuggestion) onAccept;
  final Function(TaskSuggestion) onReject;

  const EditableTaskSuggestionCard({
    super.key,
    required this.suggestion,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<EditableTaskSuggestionCard> createState() => _EditableTaskSuggestionCardState();
}

class _EditableTaskSuggestionCardState extends State<EditableTaskSuggestionCard> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _timeController;
  late TextEditingController _endTimeController;
  late TaskPriority _priority;
  late String _recurrenceType;
  late String _itemType;
  late DateTime _taskDate;
  String? _selectedSpaceId;
  String? _selectedSpaceName;
  List<int>? _weeklyDays;
  DateTime? _endDate;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.suggestion.title);
    _descriptionController = TextEditingController(text: widget.suggestion.description ?? '');
    _timeController = TextEditingController(
      text: widget.suggestion.calculatedTime ?? widget.suggestion.absoluteTime ?? '',
    );
    _endTimeController = TextEditingController(
      text: widget.suggestion.endTime ?? '',
    );
    _priority = widget.suggestion.priority;
    _recurrenceType = widget.suggestion.recurrenceType;
    _itemType = 'task'; // Default to task
    // Initialize task date from suggestion
    _taskDate = DateTime.now();
    if (widget.suggestion.taskDate != null) {
      if (widget.suggestion.taskDate!.toLowerCase() == 'tomorrow') {
        _taskDate = DateTime.now().add(const Duration(days: 1));
      } else if (widget.suggestion.taskDate!.toLowerCase() != 'today') {
        // Try to parse specific date
        final parsed = DateTime.tryParse(widget.suggestion.taskDate!);
        if (parsed != null) {
          _taskDate = parsed;
        }
      }
    }
    _weeklyDays = widget.suggestion.weeklyDays;
    _endDate = widget.suggestion.endDate != null ? DateTime.tryParse(widget.suggestion.endDate!) : null;
    
    // Extract space info from description if present
    _extractSpaceInfo();
  }
  
  void _extractSpaceInfo() {
    if (widget.suggestion.description != null) {
      final spaceMatch = RegExp(r'#(\w+)').firstMatch(widget.suggestion.description!);
      if (spaceMatch != null) {
        _selectedSpaceId = spaceMatch.group(1);
        // Try to find space name from SpaceService
        SpaceService.getAllSpaces().then((spaces) {
          final space = spaces.firstWhere(
            (s) => s.id == _selectedSpaceId,
            orElse: () => Space(id: '', name: '', color: 'blue', createdAt: DateTime.now()),
          );
          if (space.id.isNotEmpty && mounted) {
            setState(() {
              _selectedSpaceName = space.name;
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _timeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _acceptWithEdits() {
    // Update description with space tag if needed
    String? finalDescription = _descriptionController.text.isEmpty ? null : _descriptionController.text;
    if (_selectedSpaceId != null && finalDescription != null) {
      // Remove old space tag if present
      finalDescription = finalDescription.replaceAll(RegExp(r'#\w+'), '');
      // Add new space tag
      finalDescription = finalDescription.trim();
      finalDescription = finalDescription.isEmpty ? '#$_selectedSpaceId' : '$finalDescription #$_selectedSpaceId';
    } else if (_selectedSpaceId != null) {
      finalDescription = '#$_selectedSpaceId';
    }
    
    // Create updated suggestion
    final updatedSuggestion = TaskSuggestion(
      title: _titleController.text,
      description: finalDescription,
      scheduleType: widget.suggestion.scheduleType,
      absoluteTime: _timeController.text,
      endTime: _endTimeController.text.isEmpty ? null : _endTimeController.text,
      taskDate: _taskDate.isAtSameMomentAs(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)) 
          ? 'today' 
          : (_taskDate.isAtSameMomentAs(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).add(const Duration(days: 1))) 
              ? 'tomorrow' 
              : _taskDate.toIso8601String()),
      relatedPrayer: widget.suggestion.relatedPrayer,
      isBeforePrayer: widget.suggestion.isBeforePrayer,
      minutesOffset: widget.suggestion.minutesOffset,
      recurrenceType: _recurrenceType,
      priority: _priority,
      weeklyDays: _weeklyDays ?? widget.suggestion.weeklyDays,
      endDate: _endDate?.toIso8601String() ?? widget.suggestion.endDate,
      reasoningNotes: widget.suggestion.reasoningNotes,
      energyLevel: widget.suggestion.energyLevel,
    );
    
    widget.onAccept(updatedSuggestion);
  }

  @override
  Widget build(BuildContext context) {
    final hasExactTime = widget.suggestion.calculatedTime != null || widget.suggestion.absoluteTime != null;
    final displayTime = widget.suggestion.calculatedTime ?? widget.suggestion.absoluteTime ?? widget.suggestion.schedulingInfo;
    
    return Container(
      margin: const EdgeInsets.only(top: AppTheme.space8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.shadowSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and actions
          Container(
            padding: const EdgeInsets.all(AppTheme.space16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusMedium),
                topRight: Radius.circular(AppTheme.radiusMedium),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _isEditing
                          ? TextField(
                              controller: _titleController,
                              style: AppTheme.titleMedium.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                              ),
                            )
                          : Text(
                              _titleController.text,
                              style: AppTheme.titleMedium.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      if (_isEditing || _descriptionController.text.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.space4),
                        _isEditing
                            ? TextField(
                                controller: _descriptionController,
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  hintText: 'Add description...',
                                  hintStyle: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textTertiary,
                                  ),
                                ),
                              )
                            : Text(
                                _descriptionController.text,
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _toggleEdit,
                      icon: Icon(_isEditing ? Icons.close : Icons.edit),
                      color: AppTheme.textSecondary,
                      tooltip: _isEditing ? 'Cancel Edit' : 'Edit',
                    ),
                    IconButton(
                      onPressed: _acceptWithEdits,
                      icon: const Icon(Icons.check_circle),
                      color: AppTheme.success,
                      tooltip: 'Accept',
                    ),
                    IconButton(
                      onPressed: () => widget.onReject(widget.suggestion),
                      icon: const Icon(Icons.cancel),
                      color: AppTheme.error,
                      tooltip: 'Reject',
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Details section
          Padding(
            padding: const EdgeInsets.all(AppTheme.space16),
            child: Column(
              children: [
                // Time information
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space8),
                      decoration: BoxDecoration(
                        color: hasExactTime 
                            ? AppTheme.success.withOpacity(0.1)
                            : AppTheme.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Icon(
                        Icons.schedule,
                        size: 20,
                        color: hasExactTime ? AppTheme.success : AppTheme.warning,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasExactTime ? 'Scheduled Time' : 'Timing',
                            style: AppTheme.labelSmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          _isEditing
                              ? TextField(
                                  controller: _timeController,
                                  style: AppTheme.titleMedium.copyWith(
                                    color: hasExactTime ? AppTheme.success : AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    border: InputBorder.none,
                                    hintText: 'e.g., 14:30 or 2:30 PM',
                                    hintStyle: AppTheme.bodySmall.copyWith(
                                      color: AppTheme.textTertiary,
                                    ),
                                  ),
                                )
                              : Text(
                                  _timeController.text.isEmpty ? displayTime : _timeController.text,
                                  style: AppTheme.titleMedium.copyWith(
                                    color: hasExactTime ? AppTheme.success : AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space12),
                // Priority and recurrence
                Row(
                  children: [
                    // Priority chip
                    _isEditing
                        ? PopupMenuButton<TaskPriority>(
                            initialValue: _priority,
                            onSelected: (value) => setState(() => _priority = value),
                            itemBuilder: (context) => TaskPriority.values.map((priority) {
                              return PopupMenuItem(
                                value: priority,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.flag,
                                      size: 16,
                                      color: _getPriorityColor(priority),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(priority.name.toUpperCase()),
                                  ],
                                ),
                              );
                            }).toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.space12,
                                vertical: AppTheme.space6,
                              ),
                              decoration: BoxDecoration(
                                color: _getPriorityColor(_priority).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusCircular),
                                border: Border.all(
                                  color: _getPriorityColor(_priority).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.flag,
                                    size: 14,
                                    color: _getPriorityColor(_priority),
                                  ),
                                  const SizedBox(width: AppTheme.space4),
                                  Text(
                                    _priority.name.toUpperCase(),
                                    style: AppTheme.labelSmall.copyWith(
                                      color: _getPriorityColor(_priority),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.space4),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    size: 16,
                                    color: _getPriorityColor(_priority),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.space12,
                              vertical: AppTheme.space6,
                            ),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(_priority).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusCircular),
                              border: Border.all(
                                color: _getPriorityColor(_priority).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.flag,
                                  size: 14,
                                  color: _getPriorityColor(_priority),
                                ),
                                const SizedBox(width: AppTheme.space4),
                                Text(
                                  _priority.name.toUpperCase(),
                                  style: AppTheme.labelSmall.copyWith(
                                    color: _getPriorityColor(_priority),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                    const SizedBox(width: AppTheme.space8),
                    // Recurrence chip
                    _isEditing
                        ? PopupMenuButton<String>(
                            initialValue: _recurrenceType,
                            onSelected: (value) => setState(() => _recurrenceType = value),
                            itemBuilder: (context) => ['once', 'daily', 'weekly', 'monthly'].map((type) {
                              return PopupMenuItem(
                                value: type,
                                child: Row(
                                  children: [
                                    Icon(
                                      type == 'once' ? Icons.event : Icons.repeat,
                                      size: 16,
                                      color: AppTheme.info,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(type.toUpperCase()),
                                  ],
                                ),
                              );
                            }).toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.space12,
                                vertical: AppTheme.space6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.info.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusCircular),
                                border: Border.all(
                                  color: AppTheme.info.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _recurrenceType == 'once' ? Icons.event : Icons.repeat,
                                    size: 14,
                                    color: AppTheme.info,
                                  ),
                                  const SizedBox(width: AppTheme.space4),
                                  Text(
                                    _recurrenceType.toUpperCase(),
                                    style: AppTheme.labelSmall.copyWith(
                                      color: AppTheme.info,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.space4),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    size: 16,
                                    color: AppTheme.info,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.space12,
                              vertical: AppTheme.space6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.info.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusCircular),
                              border: Border.all(
                                color: AppTheme.info.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _recurrenceType == 'once' ? Icons.event : Icons.repeat,
                                  size: 14,
                                  color: AppTheme.info,
                                ),
                                const SizedBox(width: AppTheme.space4),
                                Text(
                                  _recurrenceType.toUpperCase(),
                                  style: AppTheme.labelSmall.copyWith(
                                    color: AppTheme.info,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ],
                ),
                
                // Item Type Section
                const SizedBox(height: AppTheme.space16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Type',
                      style: AppTheme.labelMedium.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space8),
                    if (_isEditing)
                      Wrap(
                        spacing: AppTheme.space8,
                        runSpacing: AppTheme.space8,
                        children: [
                          _buildTypeChip('task', Icons.check_circle_outline),
                          _buildTypeChip('activity', Icons.directions_run),
                          _buildTypeChip('event', Icons.event),
                          _buildTypeChip('session', Icons.laptop),
                          _buildTypeChip('routine', Icons.refresh),
                          _buildTypeChip('appointment', Icons.people),
                          _buildTypeChip('reminder', Icons.notifications),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space12,
                          vertical: AppTheme.space6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusCircular),
                          border: Border.all(
                            color: AppTheme.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getTypeIcon(_itemType),
                              size: 14,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(width: AppTheme.space4),
                            Text(
                              _itemType.toUpperCase(),
                              style: AppTheme.labelSmall.copyWith(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                
                // End Time Section (always show if end time exists or in edit mode)
                if (_endTimeController.text.isNotEmpty || _isEditing || _itemType != 'task' || _recurrenceType != 'once') ...[
                  const SizedBox(height: AppTheme.space16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppTheme.space8),
                        decoration: BoxDecoration(
                          color: AppTheme.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Icon(
                          Icons.access_time_filled,
                          size: 20,
                          color: AppTheme.info,
                        ),
                      ),
                      const SizedBox(width: AppTheme.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'End Time',
                              style: AppTheme.labelSmall.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            _isEditing
                                ? TextField(
                                    controller: _endTimeController,
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: AppTheme.textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      border: InputBorder.none,
                                      hintText: 'Optional end time',
                                      hintStyle: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.textTertiary,
                                      ),
                                    ),
                                  )
                                : Text(
                                    _endTimeController.text.isEmpty ? 'Not specified' : _endTimeController.text,
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                
                // Task Date
                const SizedBox(height: AppTheme.space16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space12,
                    vertical: AppTheme.space8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: AppTheme.space8),
                      Expanded(
                        child: Text(
                          _taskDate.isAtSameMomentAs(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))
                              ? 'Today - ${DateFormat('EEEE, MMMM d, yyyy').format(_taskDate)}'
                              : DateFormat('EEEE, MMMM d, yyyy').format(_taskDate),
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (_isEditing)
                        IconButton(
                          icon: const Icon(Icons.edit_calendar, size: 18),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _taskDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => _taskDate = picked);
                            }
                          },
                          color: AppTheme.textSecondary,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ),
                
                // Space Assignment
                if (_selectedSpaceId != null || _isEditing) ...[
                  const SizedBox(height: AppTheme.space16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppTheme.space8),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Icon(
                          Icons.folder,
                          size: 20,
                          color: AppTheme.secondary,
                        ),
                      ),
                      const SizedBox(width: AppTheme.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Space',
                              style: AppTheme.labelSmall.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Text(
                              _selectedSpaceName ?? 'No space assigned',
                              style: AppTheme.bodyMedium.copyWith(
                                color: _selectedSpaceName != null ? AppTheme.textPrimary : AppTheme.textTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isEditing)
                        TextButton(
                          onPressed: () async {
                            final spaces = await SpaceService.getAllSpaces();
                            if (!mounted) return;
                            
                            final selected = await showDialog<Space>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Select Space'),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: spaces.length + 1,
                                    itemBuilder: (context, index) {
                                      if (index == 0) {
                                        return ListTile(
                                          leading: const Icon(Icons.clear),
                                          title: const Text('No space'),
                                          onTap: () => Navigator.pop(context, null),
                                        );
                                      }
                                      final space = spaces[index - 1];
                                      return ListTile(
                                        leading: Icon(
                                          Icons.folder,
                                          color: _getSpaceColor(space.color ?? 'blue'),
                                        ),
                                        title: Text(space.name),
                                        onTap: () => Navigator.pop(context, space),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                            
                            setState(() {
                              if (selected != null) {
                                _selectedSpaceId = selected.id;
                                _selectedSpaceName = selected.name;
                              } else {
                                _selectedSpaceId = null;
                                _selectedSpaceName = null;
                              }
                            });
                          },
                          child: const Text('Change'),
                        ),
                    ],
                  ),
                ],
                
                // Recurrence End Date (if recurring)
                if (_recurrenceType != 'once' && (_endDate != null || _isEditing)) ...[
                  const SizedBox(height: AppTheme.space12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space12,
                      vertical: AppTheme.space8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_repeat,
                          size: 16,
                          color: AppTheme.warning,
                        ),
                        const SizedBox(width: AppTheme.space8),
                        Expanded(
                          child: Text(
                            _endDate != null
                                ? 'Ends on ${DateFormat('MMM d, yyyy').format(_endDate!)}'
                                : 'No end date',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (_isEditing)
                          IconButton(
                            icon: Icon(
                              _endDate != null ? Icons.edit : Icons.add,
                              size: 18,
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _endDate ?? DateTime.now().add(const Duration(days: 30)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null || _endDate != null) {
                                setState(() => _endDate = picked);
                              }
                            },
                            color: AppTheme.textSecondary,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTypeChip(String type, IconData icon) {
    final isSelected = _itemType == type;
    return InkWell(
      onTap: () => setState(() => _itemType = type),
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space12,
          vertical: AppTheme.space6,
        ),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primary.withOpacity(0.1)
              : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(
            color: isSelected 
                ? AppTheme.primary.withOpacity(0.3)
                : AppTheme.borderLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(width: AppTheme.space4),
            Text(
              type.toUpperCase(),
              style: AppTheme.labelSmall.copyWith(
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'task':
        return Icons.check_circle_outline;
      case 'activity':
        return Icons.directions_run;
      case 'event':
        return Icons.event;
      case 'session':
        return Icons.laptop;
      case 'routine':
        return Icons.refresh;
      case 'appointment':
        return Icons.people;
      case 'reminder':
        return Icons.notifications;
      default:
        return Icons.task_alt;
    }
  }
  
  Color _getSpaceColor(String colorName) {
    final colors = {
      'blue': Colors.blue,
      'green': Colors.green,
      'purple': Colors.purple,
      'orange': Colors.orange,
      'pink': Colors.pink,
      'teal': Colors.teal,
      'red': Colors.red,
      'indigo': Colors.indigo,
    };
    return colors[colorName] ?? Colors.blue;
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
}

// Editable Space Suggestion Card
class EditableSpaceSuggestionCard extends StatefulWidget {
  final SpaceSuggestion suggestion;
  final Function(SpaceSuggestion) onAccept;
  final Function(SpaceSuggestion) onReject;

  const EditableSpaceSuggestionCard({
    super.key,
    required this.suggestion,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<EditableSpaceSuggestionCard> createState() => _EditableSpaceSuggestionCardState();
}

class _EditableSpaceSuggestionCardState extends State<EditableSpaceSuggestionCard> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late String _selectedColor;
  bool _isEditing = false;
  
  final List<String> _availableColors = [
    'blue', 'green', 'purple', 'orange', 'pink', 'teal', 'red', 'indigo'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.suggestion.name);
    _descriptionController = TextEditingController(text: widget.suggestion.description ?? '');
    _selectedColor = widget.suggestion.color;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _acceptWithEdits() {
    // Create updated suggestion
    final updatedSuggestion = SpaceSuggestion(
      name: _nameController.text,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      color: _selectedColor,
      dueDate: widget.suggestion.dueDate,
    );
    
    widget.onAccept(updatedSuggestion);
  }
  
  Color _getSpaceColor(String colorName) {
    final colors = {
      'blue': Colors.blue,
      'green': Colors.green,
      'purple': Colors.purple,
      'orange': Colors.orange,
      'pink': Colors.pink,
      'teal': Colors.teal,
      'red': Colors.red,
      'indigo': Colors.indigo,
    };
    return colors[colorName] ?? Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppTheme.space8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.shadowSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and actions
          Container(
            padding: const EdgeInsets.all(AppTheme.space16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusMedium),
                topRight: Radius.circular(AppTheme.radiusMedium),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _isEditing
                          ? TextField(
                              controller: _nameController,
                              style: AppTheme.titleMedium.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                              ),
                            )
                          : Text(
                              _nameController.text,
                              style: AppTheme.titleMedium.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      if (_isEditing || _descriptionController.text.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.space4),
                        _isEditing
                            ? TextField(
                                controller: _descriptionController,
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  hintText: 'Add description...',
                                  hintStyle: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textTertiary,
                                  ),
                                ),
                              )
                            : Text(
                                _descriptionController.text,
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _toggleEdit,
                      icon: Icon(_isEditing ? Icons.close : Icons.edit),
                      color: AppTheme.textSecondary,
                      tooltip: _isEditing ? 'Cancel Edit' : 'Edit',
                    ),
                    IconButton(
                      onPressed: _acceptWithEdits,
                      icon: const Icon(Icons.check_circle),
                      color: AppTheme.success,
                      tooltip: 'Create Space',
                    ),
                    IconButton(
                      onPressed: () => widget.onReject(widget.suggestion),
                      icon: const Icon(Icons.cancel),
                      color: AppTheme.error,
                      tooltip: 'Cancel',
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Space details
          Padding(
            padding: const EdgeInsets.all(AppTheme.space16),
            child: Row(
              children: [
                // Color selector
                if (_isEditing)
                  Expanded(
                    child: Wrap(
                      spacing: AppTheme.space8,
                      runSpacing: AppTheme.space8,
                      children: _availableColors.map((color) {
                        final isSelected = color == _selectedColor;
                        return InkWell(
                          onTap: () => setState(() => _selectedColor = color),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _getSpaceColor(color),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              border: Border.all(
                                color: isSelected 
                                    ? AppTheme.textPrimary 
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  )
                else
                  Row(
                    children: [
                      // Color indicator
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getSpaceColor(_selectedColor),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: const Icon(
                          Icons.folder,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppTheme.space16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Space Color',
                            style: AppTheme.labelSmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            _selectedColor.toUpperCase(),
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}