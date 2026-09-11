import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import 'package:crm_app/services/language_service.dart';

// Message Model
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? sender;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.sender,
  });
}

// Language Model
class Language {
  final String name;
  final String code;
  final int number;

  Language({
    required this.name,
    required this.code,
    required this.number,
  });
}

// Chat Controller
class ChatController extends GetxController {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final RxBool isTyping = false.obs;
  final RxBool showLanguageSelection = true.obs;

  final List<Language> languages = [
    Language(name: 'English', code: 'en', number: 1),
    Language(name: 'Hindi', code: 'hi', number: 2),
    Language(name: 'Bahasa Melayu', code: 'ms', number: 3),
    Language(name: 'Bahasa Indonesia', code: 'id', number: 4),
  ];

  @override
  void onInit() {
    super.onInit();
    _initializeChat();
  }

  void _initializeChat() {
    // Initial bot messages
    messages.addAll([
      ChatMessage(
        text: "Hi, there!",
        isUser: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        sender: "App Assistant",
      ),
      ChatMessage(
        text: "Welcome to App. How can we help you today?",
        isUser: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        sender: "App Assistant",
      ),
    ]);

    // User's response
    Future.delayed(const Duration(milliseconds: 500), () {
      messages.add(ChatMessage(
        text: "Hi there!",
        isUser: true,
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      ));

      // Bot's follow-up
      Future.delayed(const Duration(milliseconds: 1000), () {
        messages.add(ChatMessage(
          text: "Hello, Brooklyn! Thank you for contacting App.",
          isUser: false,
          timestamp: DateTime.now().subtract(const Duration(seconds: 30)),
          sender: "App Assistant",
        ));

        Future.delayed(const Duration(milliseconds: 1500), () {
          messages.add(ChatMessage(
            text: "Please select the department where you want to get assistance.",
            isUser: false,
            timestamp: DateTime.now(),
            sender: "App Assistant",
          ));
          _scrollToBottom();
        });
      });
    });
  }

  void selectLanguage(Language language) {
    showLanguageSelection.value = false;
    sendMessage("I'd like assistance in ${language.name}");

    // Bot response
    Future.delayed(const Duration(milliseconds: 800), () {
      _addBotMessage("Great! I'll assist you in ${language.name}. How can I help you today?");
    });
  }

  void sendMessage(String text) {
    if (text.trim().isEmpty) return;

    messages.add(ChatMessage(
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    ));

    messageController.clear();
    _scrollToBottom();

    // Simulate bot typing
    isTyping.value = true;

    // Bot auto-response after delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      isTyping.value = false;
      _addBotMessage(_getBotResponse(text));
    });
  }

  void _addBotMessage(String text) {
    messages.add(ChatMessage(
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      sender: "App Assistant",
    ));
    _scrollToBottom();
  }

  String _getBotResponse(String userMessage) {
    // Simple bot responses
    final message = userMessage.toLowerCase();

    if (message.contains('help') || message.contains('assist')) {
      return "I'm here to help! What specific issue are you facing?";
    } else if (message.contains('account') || message.contains('balance')) {
      return "I can help you with account-related queries. Please provide more details.";
    } else if (message.contains('deposit') || message.contains('withdraw')) {
      return "For transaction assistance, I can guide you through the process. What would you like to do?";
    } else if (message.contains('thank')) {
      return "You're welcome! Is there anything else I can help you with?";
    } else {
      return "Thank you for your message. Our team will get back to you shortly. Is there anything specific I can help you with right now?";
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void openVoiceInput() {
    if (Get.isRegistered<AppNotificationController>()) {
      final lang = Get.find<LanguageService>();
      Get.find<AppNotificationController>().showInfo(
        message: lang.tr('chat_with_us_voice_input_placeholder'),
        title: lang.tr('chat_with_us_voice_input_title'),
      );
    }
  }

  void openAttachment() {
    if (Get.isRegistered<AppNotificationController>()) {
      Get.find<AppNotificationController>().showInfo(
        message: 'File attachment feature would be implemented here',
        title: 'Attachment',
      );
    }
  }

  @override
  void onClose() {
    messageController.dispose();
    scrollController.dispose();
    super.onClose();
  }
}
