import 'package:crm_app/widgets/dashBorder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';

class SubscriptionSetupScreen extends StatefulWidget {
  const SubscriptionSetupScreen({super.key});

  @override
  State<SubscriptionSetupScreen> createState() =>
      _SubscriptionSetupScreenState();
}

class _SubscriptionSetupScreenState extends State<SubscriptionSetupScreen> {
  // --- State ---
  // null = no preset selected (custom mode), otherwise index 0,1,2
  int? _selectedProportion = 0;

  bool _isCustomMode = false;
  bool _supportFundsEnabled = false;

  final TextEditingController _customValueCtrl = TextEditingController(
    text: 'x4',
  );
  final TextEditingController _supportAmountCtrl = TextEditingController(
    text: r'$75.2',
  );

  // Preset data
  final List<Map<String, String>> _presets = [
    {'label': 'Equal x1', 'required': r'$47', 'volume': 'x1 trade volume'},
    {'label': 'Equal x2', 'required': r'$94', 'volume': 'x2 trade volume'},
    {'label': 'Triple x3', 'required': r'$141', 'volume': 'x3 trade volume'},
  ];

  @override
  void dispose() {
    _customValueCtrl.dispose();
    _supportAmountCtrl.dispose();
    super.dispose();
  }

  // Computed summary values
  String get _summaryProportion {
    if (_isCustomMode) return _customValueCtrl.text.trim();
    return _presets[_selectedProportion ?? 0]['label'] ?? 'Equal x1';
  }

  String get _summaryRequired {
    if (_isCustomMode) return r'$188';
    return '${_presets[_selectedProportion ?? 0]['required']}.00';
  }

  String get _summarySupportFunds =>
      _supportFundsEnabled ? r'$75.20' : r'$0.00';

  String get _summaryTotal {
    if (_isCustomMode) {
      return _supportFundsEnabled ? r'$263.20' : r'$188.00';
    }
    final base =
        int.tryParse(
          (_presets[_selectedProportion ?? 0]['required'] ?? r'$47').replaceAll(
            r'$',
            '',
          ),
        ) ??
        47;
    final support = _supportFundsEnabled ? 75 : 0;
    return '\$${base + support}.00';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/svg/trade/arro_back.svg',
            colorFilter: ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Subscription Setup',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // ── Trader header card ────────────────────────────────────────
            _buildSectionCard(
              child: Row(
                children: [
                  SvgPicture.asset('assets/svg/copy_trading/person_svg.svg'),
                  SizedBox(width: 12),
                  Text(
                    'Prime_traders',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),

            // ── Funds in wallet ───────────────────────────────────────────
            _buildSectionCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Funds In Wallet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      SvgPicture.asset(
                        "assets/svg/copy_trading/investment/wallet.svg",
                        height: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '50.01 USD',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.icongrey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),

            // ── Copy Proportion card ──────────────────────────────────────
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Copy Proportion',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isCustomMode = !_isCustomMode;
                            if (_isCustomMode) _selectedProportion = null;
                          });
                        },
                        child: Text(
                          _isCustomMode ? '< Default' : 'Custom >',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),

                  // Default mode: 3 proportion cards
                  if (!_isCustomMode) ...[
                    Row(
                      children: List.generate(_presets.length, (i) {
                        final selected = _selectedProportion == i;
                        return Expanded(
                          child: GestureDetector(
                            onTap:
                                () => setState(() => _selectedProportion = i),
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color:
                                      selected
                                          ? AppColors.primary
                                          : AppColors.border,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    _presets[i]['label']!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          selected
                                              ? AppColors.whiteColor
                                              : AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '${_presets[i]['required']!} required',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color:
                                          selected
                                              ? AppColors.whiteColor.withOpacity(0.70)
                                              : AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    _presets[i]['volume']!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w400,
                                      color:
                                          selected
                                              ? AppColors.whiteColor.withOpacity(0.70)
                                              : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: 16),
                  ],

                  // Custom mode: text field
                  if (_isCustomMode) ...[
                    _buildLabeledField(
                      label: 'Enter Value',
                      controller: _customValueCtrl,
                      keyboardType: TextInputType.text,
                    ),
                    SizedBox(height: 6),
                    Padding(
                      padding: EdgeInsets.only(left: 2),
                      child: Text(
                        'Required investment : \$188',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.icongrey,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    SizedBox(height: 14),
                  ],

                  // Support Funds toggle row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 40,
                        child: Transform.scale(
                          scale:
                              0.8, // ← Change this value: 0.7 = smaller, 0.9 = slightly smaller, 1.0 = normal
                          child: Switch(
                            value: _supportFundsEnabled,
                            onChanged:
                                (v) => setState(() => _supportFundsEnabled = v),
                            activeThumbColor: AppColors.primary,
                            inactiveThumbColor: AppColors.whiteColor,
                            inactiveTrackColor: AppColors.switchTrackOff,
                            overlayColor: MaterialStateProperty.all(
                              Colors.transparent,
                            ),

                            // Border removal when inactive (from previous fix)
                            trackOutlineColor: MaterialStateProperty.resolveWith<
                              Color?
                            >((states) {
                              if (states.contains(MaterialState.selected))
                                return null;
                              return Colors
                                  .transparent; // or AppColors.whiteColor if background is white
                            }),
                            trackOutlineWidth:
                                MaterialStateProperty.resolveWith<double?>((
                                  states,
                                ) {
                                  if (states.contains(MaterialState.selected))
                                    return null;
                                  return 0.0;
                                }),

                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      SizedBox(width: 5),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.icongrey,
                            ),
                            children: const [
                              TextSpan(text: 'Add '),
                              TextSpan(
                                text: 'Support Funds',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text:
                                    ' to protect your investment from unexpected market movements.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Support amount field (only in custom + toggled mode)
                  if (_isCustomMode && _supportFundsEnabled) ...[
                    SizedBox(height: 12),
                    _buildLabeledField(
                      label: 'Support Amount',
                      controller: _supportAmountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    SizedBox(height: 6),
                    Padding(
                      padding: EdgeInsets.only(left: 2),
                      child: Text(
                        '39% of the required investment.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 10),

            // ── Summary card ──────────────────────────────────────────────
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 14),
                  _summaryRow('Copy proportion', _summaryProportion),
                  _summaryRow('Required Investment', _summaryRequired),
                  _summaryRow('Support Funds', _summarySupportFunds),
                  _summaryRow('Total', _summaryTotal, isBold: true),
                ],
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: AppColors.whiteColor,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        child: ElevatedButton(
          onPressed: () {
            // TODO: hook to API
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          child:   Text(
            'Start Copying',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.whiteColor,
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.border,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: child,
    );
  }

  Widget _buildLabeledField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: 15),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        Positioned(
          top: -10,
          left: 12,
          child: Container(
            color: AppColors.whiteColor,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isBold ? AppColors.textPrimary : AppColors.textGrey,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          Flexible(
            child: DashedUnderline(
              color: AppColors.dashLineColor,
              dashSpace: 3,
              dashWidth: 3,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              color: isBold ? AppColors.textPrimary : AppColors.icongrey,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
