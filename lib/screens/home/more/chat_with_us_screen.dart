import 'package:flutter/material.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/widgets/app_back_button.dart';

import 'package:crm_app/screens/more/view_models/chat_with_us_controller.dart';
import 'package:crm_app/services/language_service.dart';

class ChatWithUsScreen extends StatelessWidget {
  const ChatWithUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ChatController());
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          TranslationUtils.tr('chat_with_us'),
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Chat Messages
          Expanded(child: _buildChatBody(controller, isTablet)),

          // Input Area
          _buildMessageInput(controller, isTablet),
        ],
      ),
    );
  }

  Widget _buildChatBody(ChatController controller, bool isTablet) {
    return Obx(
      () => ListView.builder(
        controller: controller.scrollController,
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 32.0 : 16.0,
          vertical: 16.0,
        ),
        itemCount:
            controller.messages.length +
            (controller.showLanguageSelection.value ? 1 : 0) +
            (controller.isTyping.value ? 1 : 0),
        itemBuilder: (context, index) {
          // Language selection card
          if (controller.showLanguageSelection.value &&
              index == controller.messages.length) {
            return _buildLanguageSelectionCard(controller);
          }

          // Typing indicator
          if (controller.isTyping.value &&
              index ==
                  controller.messages.length +
                      (controller.showLanguageSelection.value ? 1 : 0)) {
            return _buildTypingIndicator();
          }

          // Regular message
          final message = controller.messages[index];
          return _buildMessageBubble(message, isTablet);
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isTablet) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            // Bot avatar
            Container(
              width: 32,
              height: 32,
              margin: EdgeInsetsDirectional.only(end: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child:   Icon(
                Icons.support_agent,
                color: AppColors.whiteColor,
                size: 18,
              ),
            ),
          ],

          // Message bubble
          Flexible(
            child: Column(
              crossAxisAlignment:
                  message.isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
              children: [
                if (!message.isUser && message.sender != null)
                  Padding(
                    padding: EdgeInsetsDirectional.only(bottom: 4, start: 8),
                    child: Text(
                      message.sender!,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12,
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: message.isUser ? AppColors.primary : AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 15,
                      color:
                          message.isUser
                              ? AppColors.whiteColor
                              : AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (message.isUser) ...[
            SizedBox(width: 8),
            // User avatar
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.border,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, color: AppColors.icongrey, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLanguageSelectionCard(ChatController controller) {
    return Container(
      margin: EdgeInsetsDirectional.only(bottom: 16, start: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TranslationUtils.tr(
                    'chat_with_us_screen_please_select_the_department_where_you',
                  ),
                  style: AppTextStyles.bodyText.copyWith(fontSize: 14, color: AppColors.textPrimary),
                ),
                SizedBox(height: 12),

                // Language options
                ...controller.languages
                    .map(
                      (language) => GestureDetector(
                        onTap: () => controller.selectLanguage(language),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            "${language.number}. ${language.name}",
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 14,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: EdgeInsetsDirectional.only(bottom: 16, start: 40),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                SizedBox(width: 4),
                _buildTypingDot(1),
                SizedBox(width: 4),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -4 * value),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageInput(ChatController controller, bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 32.0 : 16.0,
        vertical: 16.0,
      ),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Text input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: controller.messageController,
                  decoration: InputDecoration(
                    hintText: Get.find<LanguageService>().tr(
                      'chat_with_us_ask_me_anything',
                    ),
                    hintStyle: AppTextStyles.bodyText.copyWith(color: Colors.grey[500], fontSize: 15),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    border: InputBorder.none,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.mic,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                          onPressed: controller.openVoiceInput,
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.attach_file,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                          onPressed: controller.openAttachment,
                        ),
                      ],
                    ),
                  ),
                  onSubmitted: controller.sendMessage,
                  textInputAction: TextInputAction.send,
                ),
              ),
            ),

            SizedBox(width: 12),

            // Send button
            GestureDetector(
              onTap:
                  () =>
                      controller.sendMessage(controller.messageController.text),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child:   Icon(Icons.send, color: AppColors.whiteColor, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
