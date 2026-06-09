import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/models/ticket_model.dart';
import 'package:crm_app/screens/home/more/ticket/ticket_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({super.key});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen>
    with SingleTickerProviderStateMixin {
  final TicketController controller = Get.find<TicketController>();
  final LanguageService lang = Get.find<LanguageService>();
  final _replyController = TextEditingController();
  late final TabController _tabController;
  late final String _ticketId;

  @override
  void initState() {
    super.initState();
    _ticketId = (Get.arguments ?? '').toString();
    _tabController = TabController(length: 2, vsync: this);
    controller.fetchTicketDetail(_ticketId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final msg = _replyController.text.trim();
    if (msg.isEmpty) return;
    final ok = await controller.replyToTicket(_ticketId, msg);
    if (ok) {
      _replyController.clear();
    }
  }

  void _confirmClose() {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
        ),
        title: Text(
          lang.tr('ticket_close'),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          lang.tr('ticket_close_confirm'),
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14.sp,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              lang.tr('ticket_cancel'),
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusRed,
              foregroundColor: AppColors.pureWhite,
            ),
            onPressed: () {
              Get.back();
              controller.closeTicket(_ticketId);
            },
            child: Text(
              lang.tr('ticket_close'),
              style: TextStyle(
                color: AppColors.pureWhite,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: const AppBackButton(),
        title: Text('${lang.tr('ticket_detail')} #$_ticketId',
            style: AppTextStyles.screenTitle),
      ),
      body: Obx(() {
        if (controller.isDetailLoading.value &&
            controller.ticketDetail.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final detail = controller.ticketDetail.value;
        if (detail == null) {
          return Center(
            child: Text(
              controller.errorMessage.value.isEmpty
                  ? lang.tr('ticket_no_tickets')
                  : controller.errorMessage.value,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }
        return Column(
          children: [
            _buildInfoCard(detail.ticket),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: [
                Tab(text: lang.tr('ticket_tab_all')),
                Tab(
                    text:
                        '${lang.tr('ticket_tab_attachments')} (${detail.attachments.length})'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildConversation(detail),
                  _buildAttachments(detail),
                ],
              ),
            ),
            if (detail.ticket.isOpen) _buildReplyBar(),
          ],
        );
      }),
    );
  }

  Widget _buildInfoCard(Ticket ticket) {
    return Container(
      margin: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 14.w),
          title: Text(ticket.title, style: AppTextStyles.black14600),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 4.h),
            child: _badge(
              ticket.isOpen
                  ? lang.tr('ticket_status_open')
                  : lang.tr('ticket_status_closed'),
              ticket.isOpen ? AppColors.statusGreen : AppColors.statusGrey,
            ),
          ),
          childrenPadding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 12.h),
          children: [
            _infoRow(lang.tr('ticket_reference'), '#${ticket.id}'),
            _infoRow(lang.tr('ticket_department'), ticket.department),
            _infoRow(lang.tr('ticket_priority'), ticket.priority.toUpperCase()),
            _infoRow(lang.tr('ticket_created'), ticket.createdAt),
            _infoRow(
              lang.tr('ticket_assignee'),
              ticket.assignee?.name.isNotEmpty == true
                  ? ticket.assignee!.name
                  : lang.tr('ticket_unassigned'),
            ),
            if (ticket.isOpen) ...[
              SizedBox(height: 8.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _confirmClose,
                  icon: Icon(Icons.lock_outline,
                      size: 18.sp, color: AppColors.statusRed),
                  label: Text(lang.tr('ticket_close'),
                      style: TextStyle(color: AppColors.statusRed)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.statusRed),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConversation(TicketDetail detail) {
    if (detail.conversation.isEmpty) {
      return Center(
        child: Text(lang.tr('ticket_no_data'),
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.all(12.w),
      itemCount: detail.conversation.length,
      itemBuilder: (context, index) {
        final c = detail.conversation[index];
        final isUser = c.isUser;
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(maxWidth: 0.78.sw),
            margin: EdgeInsets.only(bottom: 12.h),
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: isUser ? AppColors.surface : AppColors.surfacePrimary,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.author.name.isNotEmpty)
                  Text(c.author.name,
                      style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                SizedBox(height: 4.h),
                Text(c.content,
                    style: TextStyle(
                        fontSize: 13.sp, color: AppColors.textPrimary)),
                if (c.attachment != null) ...[
                  SizedBox(height: 6.h),
                  GestureDetector(
                    onTap: () => controller.openAttachment(c.attachment!),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.attach_file,
                            size: 14.sp, color: AppColors.primary),
                        SizedBox(width: 4.w),
                        Flexible(
                          child: Text(
                            c.attachment!.filename,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.primary,
                                decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 4.h),
                Text(c.timestamp,
                    style: TextStyle(
                        fontSize: 10.sp, color: AppColors.textSecondary)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachments(TicketDetail detail) {
    final attachments = detail.attachments;
    if (attachments.isEmpty) {
      return Center(
        child: Text(lang.tr('ticket_no_data'),
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.all(12.w),
      itemCount: attachments.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        final a = attachments[index];
        return Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.insert_drive_file_outlined,
                  color: AppColors.primary, size: 24.sp),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  a.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 13.sp, color: AppColors.textPrimary),
                ),
              ),
              Obx(
                () => controller.isDownloading.value
                    ? SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      )
                    : IconButton(
                        onPressed: () => controller.openAttachment(a),
                        icon: Icon(Icons.download_outlined,
                            color: AppColors.primary),
                        tooltip: lang.tr('ticket_download'),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReplyBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 12.h),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    minLines: 1,
                    maxLines: 4,
                    cursorColor: AppColors.primary,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14.sp,
                    ),
                    decoration: InputDecoration(
                      hintText: lang.tr('ticket_reply_placeholder'),
                      hintStyle: TextStyle(
                        color: AppColors.hint,
                        fontSize: 13.sp,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.textFieldBg,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 10.h),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.r),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.r),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.r),
                        borderSide:
                            BorderSide(color: AppColors.border, width: 1),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                Obx(
                  () => CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: controller.isSubmitting.value
                        ? SizedBox(
                            height: 18.h,
                            width: 18.h,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.whiteColor),
                          )
                        : IconButton(
                            onPressed: _sendReply,
                            icon: Icon(Icons.send,
                                color: AppColors.whiteColor, size: 18.sp),
                          ),
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110.w,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.sp, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style:
                    TextStyle(fontSize: 12.sp, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10.sp, fontWeight: FontWeight.w600)),
    );
  }
}
