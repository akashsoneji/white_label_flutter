import 'dart:io';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/home/more/ticket/ticket_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/AppTextField.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/widgets/dashBorder.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final TicketController controller = Get.find<TicketController>();
  final LanguageService lang = Get.find<LanguageService>();
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _departmentId;
  String _priority = 'low';
  File? _attachment;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      const maxBytes = 5 * 1024 * 1024; // 5 MB
      if (await file.length() > maxBytes) {
        CustomToastService.showError(
          message: lang.tr('ticket_attachment_formats'),
        );
        return;
      }
      setState(() => _attachment = file);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await controller.createTicket(
      departmentId: _departmentId!,
      priority: _priority,
      title: _subjectController.text.trim(),
      description: _descriptionController.text.trim(),
      attachment: _attachment,
    );
    if (ok) Get.back();
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
        title:
            Text(lang.tr('ticket_new_ticket'), style: AppTextStyles.screenTitle),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            _label(lang.tr('ticket_department')),
            Obx(
              () => DropdownButtonFormField<String>(
                value: _departmentId,
                isExpanded: true,
                decoration: _inputDecoration(lang.tr('ticket_select_department')),
                dropdownColor: AppColors.card,
                items: controller.departments
                    .map((d) =>
                        DropdownMenuItem(value: d.id, child: Text(d.name,style: AppTextStyles.black14600,)))
                    .toList(),
                validator: (v) =>
                    v == null ? lang.tr('ticket_select_department') : null,
                onChanged: (v) => setState(() => _departmentId = v),
              ),
            ),
            SizedBox(height: 16.h),
            _label(lang.tr('ticket_priority')),
            DropdownButtonFormField<String>(
              value: _priority,
              isExpanded: true,
              decoration: _inputDecoration(lang.tr('ticket_select_priority')),
              dropdownColor: AppColors.card,
              items: {
                'low': lang.tr('ticket_priority_low'),
                'medium': lang.tr('ticket_priority_medium'),
                'high': lang.tr('ticket_priority_high'),
              }
                  .entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value,style: AppTextStyles.black14600,)))
                  .toList(),
              onChanged: (v) => setState(() => _priority = v ?? 'low'),
            ),
            SizedBox(height: 16.h),
            AppTextField(
              controller: _subjectController,
              label: lang.tr('ticket_subject'),
              hintText: lang.tr('ticket_subject_hint'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? lang.tr('ticket_subject')
                  : null,
            ),
            SizedBox(height: 16.h),
            AppTextField(
              controller: _descriptionController,
              label: lang.tr('ticket_description'),
              hintText: lang.tr('ticket_description_hint'),
              maxLines: 5,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? lang.tr('ticket_description')
                  : null,
            ),
            SizedBox(height: 16.h),
            _label(lang.tr('ticket_attachment')),
            _buildAttachment(),
            SizedBox(height: 24.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      side: BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: Text(lang.tr('ticket_cancel'),
                        style: TextStyle(color: AppColors.textPrimary)),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Obx(
                    () => ElevatedButton(
                      onPressed:
                          controller.isSubmitting.value ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      child: controller.isSubmitting.value
                          ? SizedBox(
                              height: 18.h,
                              width: 18.h,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.whiteColor,
                              ),
                            )
                          : Text(
                              lang.tr('ticket_create'),
                              style: TextStyle(
                                  color: AppColors.whiteColor,
                                  fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildAttachment() {
    if (_attachment != null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.insert_drive_file_outlined,
                color: AppColors.primary, size: 20.sp),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                _attachment!.path.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.sp, color: AppColors.textPrimary),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _attachment = null),
              child: Icon(Icons.close, size: 18.sp, color: AppColors.iconGrey),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: _pickFile,
      child: DashedBorderBox(
        color: AppColors.border,
        radius: 10.r,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 30.h, horizontal: 12.w),
          child: Column(
            children: [
              Icon(Icons.upload, color: AppColors.primary, size: 22.sp),
              SizedBox(height: 8.h),
              Text(
                lang.tr('ticket_attach_files'),
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                lang.tr('ticket_attachment_formats'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11.sp, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: EdgeInsets.only(bottom: 6.h),
        child: Text(text, style: AppTextStyles.label),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.hint, fontSize: 13.sp),
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: AppColors.primary),
        ),
      );
}
