import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';
import 'package:crm_app/widgets/AppTextField.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/screens/ibm/presentation/widgets/ibm_top_header.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:url_launcher/url_launcher.dart';

class IbmMarketingScreen extends StatefulWidget {
  /// When true the screen omits its own [IbmTopHeader] because it is being
  /// hosted inside another screen (the More tab) that already shows a header.
  final bool embedded;
  const IbmMarketingScreen({super.key, this.embedded = false});

  @override
  State<IbmMarketingScreen> createState() => _IbmMarketingScreenState();
}

class _IbmMarketingScreenState extends State<IbmMarketingScreen> {
  final IbmController controller = Get.find<IbmController>();
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchMarketingMaterials();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String val) {
    controller.fetchMarketingMaterials(q: val.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: widget.embedded
          ? null
          : IbmTopHeader(
              title: TranslationUtils.tr('ibm_marketing_material'),
              showBackButton: false,
            ),
      body: Obx(() {
        final materials = controller.materialsList;
        final categories = controller.marketingCategories;
        final selectedCat = controller.selectedMarketingCategory.value;

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await controller.fetchMarketingMaterials();
          },
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // Header title
              Text(
                TranslationUtils.tr('ibm_marketing_material'),
                style: AppTextStyles.heading.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                TranslationUtils.tr('ibm_banners_decks_and_copy'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 11.sp,
                  color: AppColors.textGrey,
                ),
              ),
              SizedBox(height: 14.h),

              // Search Bar
              AppTextField(
                controller: _searchCtrl,
                hintText: TranslationUtils.tr('ibm_search_material'),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18.w,
                  color: AppColors.textGrey,
                ),
                suffixIcon:
                    _searchCtrl.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearch('');
                          },
                        )
                        : null,
                onChanged: (val) {
                  _onSearch(val);
                },
              ),
              SizedBox(height: 12.h),

              // Category Filter Pills (if categories returned)
              if (categories.isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCatPill(
                        'all',
                        TranslationUtils.tr('common_all'),
                        selectedCat == 'all',
                      ),
                      ...categories.map((c) {
                        final key = c is Map ? (c['key'] ?? '') : c.toString();
                        final label = c is Map ? (c['label'] ?? key) : key;
                        final count = c is Map ? (c['count'] ?? 0) : 0;
                        return _buildCatPill(
                          key,
                          count > 0 ? '$label ($count)' : '$label',
                          selectedCat.toLowerCase() == key.toLowerCase(),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                SizedBox(height: 14.h),
              ],

              // Loading or Content
              if (controller.isMarketingLoading.value && materials.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.h),
                  child: Center(
                    child: CommonLoadingWidget(
                      size: 40.0,
                      color: AppColors.primary,
                    ),
                  ),
                )
              else if (materials.isEmpty)
                _buildEmptyState()
              else
                ...materials.map((m) => _buildMaterialCard(m)).toList(),

              SizedBox(height: 30.h),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCatPill(String key, String label, bool isSelected) {
    return Padding(
      padding: EdgeInsetsDirectional.only(end: 6.w),
      child: InkWell(
        onTap: () {
          controller.fetchMarketingMaterials(category: key);
        },
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? AppColors.primary
                    : (AppColors.isDarkMode
                        ? Colors.grey[800]
                        : const Color(0xFFF1F1F4)),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.whiteColor : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: EdgeInsets.only(top: 16.h),
      padding: EdgeInsets.symmetric(vertical: 60.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: AppColors.isDarkMode ? AppColors.card : AppColors.card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.image_outlined,
                size: 36.w,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              TranslationUtils.tr('ibm_nothing_published_yet'),
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              TranslationUtils.tr('ibm_broker_publishes_show_up_here'),
              style: TextStyle(
                fontSize: 11.sp,
                color: AppColors.textGrey,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialCard(dynamic item) {
    if (item is! Map) return const SizedBox();

    final materialId = (item['material_id'] ?? item['id'] ?? 0) as int;
    final title =
        item['title']?.toString() ?? TranslationUtils.tr('ibm_marketing_asset');
    final desc = item['description']?.toString() ?? '';
    final categoryLabel =
        item['category_label']?.toString() ??
        item['category']?.toString() ??
        TranslationUtils.tr('ibm_asset');
    final dimensions = item['dimensions']?.toString() ?? '';
    final language = item['language']?.toString() ?? 'EN';
    final thumbnailUrl = item['thumbnail_url']?.toString() ?? '';
    final externalUrl = item['external_url']?.toString() ?? '';
    final downloadCount = item['download_count'] ?? 0;

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.isDarkMode ? AppColors.card : AppColors.card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail or Preview
          if (thumbnailUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: Image.network(
                thumbnailUrl,
                height: 140.h,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),
          if (thumbnailUrl.isNotEmpty) SizedBox(height: 10.h),

          // Title & Category Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  categoryLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (desc.isNotEmpty) ...[
            SizedBox(height: 4.h),
            Text(
              desc,
              style: TextStyle(fontSize: 11.sp, color: AppColors.textGrey),
            ),
          ],
          SizedBox(height: 8.h),

          // Meta Row (Dimensions, Language, Downloads)
          Wrap(
            spacing: 10.w,
            children: [
              if (dimensions.isNotEmpty)
                _buildTag(Icons.aspect_ratio, dimensions),
              _buildTag(Icons.language, language.toUpperCase()),
              _buildTag(
                Icons.download_done,
                TranslationUtils.trArgs('ibm_downloads_count', {
                  'count': '$downloadCount',
                }),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Action Buttons: Download & Copy / Open Link
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleDownload(materialId, externalUrl),
                  icon: Icon(
                    Icons.file_download_outlined,
                    size: 16.w,
                    color: AppColors.whiteColor,
                  ),
                  label: Text(
                    TranslationUtils.tr('ibm_download_asset'),
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.whiteColor,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                ),
              ),
              if (externalUrl.isNotEmpty) ...[
                SizedBox(width: 8.w),
                OutlinedButton(
                  onPressed: () async {
                    final uri = Uri.tryParse(externalUrl);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: const Icon(Icons.open_in_new, size: 16),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.w, color: AppColors.textGrey),
        SizedBox(width: 3.w),
        Text(
          text,
          style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey),
        ),
      ],
    );
  }

  void _handleDownload(int materialId, String externalUrl) async {
    if (externalUrl.isNotEmpty) {
      final uri = Uri.tryParse(externalUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    CustomToastService.showSuccess(
      message: TranslationUtils.tr('ibm_starting_material_download'),
    );
  }
}
