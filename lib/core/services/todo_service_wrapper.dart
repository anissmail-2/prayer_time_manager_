/// Wrapper that automatically uses Firestore when authenticated, local storage otherwise
/// This allows gradual migration without breaking existing code
library;

import 'firestore_todo_service.dart';

export 'firestore_todo_service.dart' show FirestoreTodoService;

// Re-export all methods from FirestoreTodoService as TodoService
class TodoService {
  static getAllTasks() => FirestoreTodoService.getAllTasks();
  static addTask(task) => FirestoreTodoService.addTask(task);
  static updateTask(task) => FirestoreTodoService.updateTask(task);
  static deleteTask(taskId) => FirestoreTodoService.deleteTask(taskId);
  static toggleTaskCompletion(taskId, date) => FirestoreTodoService.toggleTaskCompletion(taskId, date);
  static markTaskAsCompleted(taskId, date) => FirestoreTodoService.markTaskAsCompleted(taskId, date);
  static getTasksForDate(date) => FirestoreTodoService.getTasksForDate(date);
  static createTaskFromSuggestion(suggestion) => FirestoreTodoService.createTaskFromSuggestion(suggestion);
  static watchTasks() => FirestoreTodoService.watchTasks();
}