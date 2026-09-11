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
    Language(
      name: 'Bahasa Melayu',
      code: 'ms',
      number: 3,
    ),
    Language(
      name: 'Bahasa Indonesia',
      code: 'id',
      number: 4,
    ),
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
        text: TranslationUtils.tr('chat_hi_there_comma'),
        isUser: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        sender: TranslationUtils.tr('chat_app_assistant'),
      ),
      ChatMessage(
        text: TranslationUtils.tr('chat_welcome_how_can_we_help'),
        isUser: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        sender: TranslationUtils.tr('chat_app_assistant'),
      ),
    ]);

    // User's response
    Future.delayed(const Duration(milliseconds: 500), () {
      messages.add(ChatMessage(
        text: TranslationUtils.tr('chat_hi_there'),
        isUser: true,
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      ));

      // Bot's follow-up
      Future.delayed(const Duration(milliseconds: 1000), () {
        messages.add(ChatMessage(
          text: TranslationUtils.tr('chat_hello_thank_you_for_contacting'),
          isUser: false,
          timestamp: DateTime.now().subtract(const Duration(seconds: 30)),
          sender: TranslationUtils.tr('chat_app_assistant'),
        ));

        Future.delayed(const Duration(milliseconds: 1500), () {
          messages.add(ChatMessage(
            text: TranslationUtils.tr(
              'chat_with_us_screen_please_select_the_department_where_you',
            ),
            isUser: false,
            timestamp: DateTime.now(),
            sender: TranslationUtils.tr('chat_app_assistant'),
          ));
          _scrollToBottom();
        });
      });
    });
  }

  void selectLanguage(Language language) {
    showLanguageSelection.value = false;
    sendMessage(
      TranslationUtils.trArgs('chat_id_like_assistance_in', {
        'language': language.name,
      }),
    );

    // Bot response
    Future.delayed(const Duration(milliseconds: 800), () {
      _addBotMessage(
        TranslationUtils.trArgs('chat_great_ill_assist_you_in', {
          'language': language.name,
        }),
      );
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
      sender: TranslationUtils.tr('chat_app_assistant'),
    ));
    _scrollToBottom();
  }

  String _getBotResponse(String userMessage) {
    // Simple bot responses
    final message = userMessage.toLowerCase();

    if (message.contains('help') || message.contains('assist')) {
      return TranslationUtils.tr('chat_bot_here_to_help');
    } else if (message.contains('account') || message.contains('balance')) {
      return TranslationUtils.tr('chat_bot_account_queries');
    } else if (message.contains('deposit') || message.contains('withdraw')) {
      return TranslationUtils.tr('chat_bot_transaction_assistance');
    } else if (message.contains('thank')) {
      return TranslationUtils.tr('chat_bot_youre_welcome');
    } else {
      return TranslationUtils.tr('chat_bot_team_will_get_back');
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
        title: TranslationUtils.tr('chat_attachment'),
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
