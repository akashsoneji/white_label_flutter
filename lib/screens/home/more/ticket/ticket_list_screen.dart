import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/models/ticket_model.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/home/more/ticket/ticket_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class TicketListScreen extends StatefulWidget {
  const TicketListScreen({super.key});

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  final TicketController controller = Get.find<TicketController>();
  final LanguageService lang = Get.find<LanguageService>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      controller.fetchTickets();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
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
        title: Text(lang.tr('ticket_title'), style: AppTextStyles.screenTitle),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 4.h),
        child: Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(24.r),
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(24.r),
            onTap: () => Get.toNamed(AppPages.TICKET_CREATE),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 18.sp, color: AppColors.whiteColor),
                  SizedBox(width: 6.w),
                  Text(
                    lang.tr('ticket_new_ticket'),
                    style: AppTextStyles.bodyText.copyWith(
                      color: AppColors.whiteColor,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildDepartmentChips(),
          _buildSearchBar(),
          _buildFilterRow(),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return Center(child: CircularProgressIndicator());
              }
              if (controller.tickets.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () => controller.fetchTickets(refresh: true),
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: _buildEmptyState(),
                      ),
                    ),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () => controller.fetchTickets(refresh: true),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 90.h),
                  itemCount: controller.tickets.length +
                      (controller.hasMorePages.value ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= controller.tickets.length) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    return _TicketCard(
                      ticket: controller.tickets[index],
                      lang: lang,
                      onTap: () => Get.toNamed(
                        AppPages.TICKET_DETAIL,
                        arguments: controller.tickets[index].id,
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentChips() {
    return Obx(() {
      if (controller.departments.isEmpty) return const SizedBox.shrink();
      // Read the observable HERE (inside the Obx builder) so the Obx subscribes
      // to it. ListView's itemBuilder runs lazily and is NOT tracked by Obx.
      final selectedId = controller.selectedDepartment.value;
      final items = <TicketDepartment>[
        TicketDepartment(id: 'all', name: lang.tr('ticket_all_tickets')),
        ...controller.departments,
      ];
      return SizedBox(
        height: 44.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
          itemCount: items.length,
          separatorBuilder: (_, __) => SizedBox(width: 8.w),
          itemBuilder: (context, index) {
            final dep = items[index];
            final selected = selectedId == dep.id;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => controller.setDepartment(dep.id),
              child: Container(
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  dep.name,
                  style: AppTextStyles.bodyText.copyWith(
                    color: selected
                        ? AppColors.whiteColor
                        : AppColors.textPrimary,
                    fontSize: 13.sp,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: TextField(
        controller: _searchController,
        onSubmitted: controller.setSearch,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: lang.tr('ticket_search_placeholder'),
          prefixIcon: Icon(Icons.search, color: AppColors.iconGrey),
          isDense: true,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: EdgeInsets.symmetric(vertical: 10.h),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: Row(
        children: [
          Expanded(
            child: _buildDropdown(
              value: controller.selectedStatus,
              onChanged: controller.setStatus,
              items: {
                'all': lang.tr('ticket_all_status'),
                'open': lang.tr('ticket_status_open'),
                'closed': lang.tr('ticket_status_closed'),
              },
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _buildDropdown(
              value: controller.selectedPriority,
              onChanged: controller.setPriority,
              items: {
                'all': lang.tr('ticket_all_priority'),
                'low': lang.tr('ticket_priority_low'),
                'medium': lang.tr('ticket_priority_medium'),
                'high': lang.tr('ticket_priority_high'),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required RxString value,
    required void Function(String) onChanged,
    required Map<String, String> items,
  }) {
    return Obx(
      () => Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppColors.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: value.value,
            icon: Icon(Icons.keyboard_arrow_down, color: AppColors.iconGrey),
            style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary, fontSize: 13.sp),
            dropdownColor: AppColors.card,
            items: items.entries
                .map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.confirmation_number_outlined,
                size: 64.sp, color: AppColors.iconGrey),
            SizedBox(height: 16.h),
            Text(lang.tr('ticket_no_tickets'),
                style: AppTextStyles.headingblack),
            SizedBox(height: 8.h),
            Text(
              lang.tr('ticket_no_tickets_subtitle'),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(color: AppColors.textSecondary, fontSize: 13.sp),
            ),
            if (controller.hasActiveFilters) ...[
              SizedBox(height: 16.h),
              OutlinedButton(
                onPressed: () {
                  _searchController.clear();
                  controller.clearFilters();
                },
                child: Text(lang.tr('ticket_clear_filters')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Ticket ticket;
  final LanguageService lang;
  final VoidCallback onTap;

  const _TicketCard({
    required this.ticket,
    required this.lang,
    required this.onTap,
  });

  Color get _statusColor =>
      ticket.isOpen ? AppColors.statusGreen : AppColors.statusGrey;

  Color get _priorityColor {
    switch (ticket.priority.toLowerCase()) {
      case 'high':
        return AppColors.statusRed;
      case 'medium':
        return AppColors.statusYellow;
      default:
        return AppColors.statusGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('#${ticket.id}',
                    style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.textSecondary, fontSize: 12.sp)),
                const Spacer(),
                _badge(
                  ticket.isOpen
                      ? lang.tr('ticket_status_open')
                      : lang.tr('ticket_status_closed'),
                  _statusColor,
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Text(
              ticket.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.black14600,
            ),
            if (ticket.description.isNotEmpty) ...[
              SizedBox(height: 4.h),
              Text(
                ticket.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    AppTextStyles.bodyText.copyWith(color: AppColors.textSecondary, fontSize: 12.sp),
              ),
            ],
            SizedBox(height: 10.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 6.h,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (ticket.department.isNotEmpty)
                  _chip(Icons.apartment_outlined, ticket.department),
                if (ticket.priority.isNotEmpty)
                  _badge(ticket.priority.toUpperCase(), _priorityColor),
                if (ticket.createdAt.isNotEmpty)
                  _chip(Icons.schedule, ticket.createdAt),
              ],
            ),
            if (ticket.assignee != null &&
                ticket.assignee!.name.isNotEmpty) ...[
              SizedBox(height: 10.h),
              Row(
                children: [
                  CircleAvatar(
                    radius: 11.r,
                    backgroundColor: AppColors.surfacePrimary,
                    child: Text(
                      ticket.assignee!.name.characters.first.toUpperCase(),
                      style: AppTextStyles.bodyText.copyWith(
                          fontSize: 11.sp, color: AppColors.primary),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(ticket.assignee!.name,
                      style: AppTextStyles.bodyText.copyWith(
                          fontSize: 12.sp, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ],
        ),
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
      child: Text(
        text,
        style: AppTextStyles.bodyText.copyWith(
            color: color, fontSize: 10.sp, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13.sp, color: AppColors.iconGrey),
        SizedBox(width: 3.w),
        Text(text,
            style: AppTextStyles.bodyText.copyWith(fontSize: 11.sp, color: AppColors.textSecondary)),
      ],
    );
  }
}
