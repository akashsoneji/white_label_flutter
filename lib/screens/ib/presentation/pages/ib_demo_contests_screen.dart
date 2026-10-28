import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/ib/view_models/ib_demo_contest_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';

IbDemoContestController _contestController() =>
    Get.isRegistered<IbDemoContestController>()
        ? Get.find<IbDemoContestController>()
        : Get.put(IbDemoContestController());

int? _intOf(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}');

String _textOf(dynamic v) {
  final s = v?.toString() ?? '';
  return s == 'null' ? '' : s;
}

/// `2026-11-01T00:00:00+00:00` / `2026-11-01 00:00:00` → `2026-11-01`.
String _dateOf(dynamic v) {
  final s = _textOf(v);
  return s.length >= 10 ? s.substring(0, 10) : s;
}

TextStyle _label() => AppTextStyles.bodyText.copyWith(
      fontSize: 11.sp,
      color: AppColors.textSecondary,
    );

TextStyle _value() => AppTextStyles.bodyText.copyWith(
      fontSize: 13.sp,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );

/// "My contests": demo contests this IB created (`ib/demo-contest/my-contests`).
class IbDemoContestsScreen extends StatelessWidget {
  const IbDemoContestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = _contestController();
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        backgroundColor: AppColors.scaffold,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const AppBackButton(),
        centerTitle: true,
        title: Text(
          TranslationUtils.tr('ib_contest_title'),
          style: AppTextStyles.screenTitle,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.whiteColor,
        onPressed: () => Get.to(() => const IbContestFormScreen()),
        icon: const Icon(Icons.add),
        label: Text(TranslationUtils.tr('ib_contest_create')),
      ),
      body: SafeArea(
        child: Obx(() {
          if (c.isLoading.value && c.contests.isEmpty) {
            return const Center(child: CommonLoadingWidget());
          }
          if (c.errorMessage.value.isNotEmpty && c.contests.isEmpty) {
            return _Message(text: c.errorMessage.value, onRetry: c.loadContests);
          }
          if (c.contests.isEmpty) {
            return _Message(text: TranslationUtils.tr('ib_contest_empty'));
          }
          return RefreshIndicator(
            onRefresh: c.loadContests,
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 80.h),
              itemCount: c.contests.length,
              separatorBuilder: (_, __) => SizedBox(height: 10.h),
              itemBuilder: (_, i) => _ContestCard(contest: c.contests[i]),
            ),
          );
        }),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center, style: _label()),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(TranslationUtils.tr('ib_contest_retry')),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContestCard extends StatelessWidget {
  const _ContestCard({required this.contest});

  final Map<String, dynamic> contest;

  @override
  Widget build(BuildContext context) {
    final c = _contestController();
    final id = _intOf(contest['id']);
    final status = _textOf(contest['status']);
    final isCancelled = status.toLowerCase() == 'cancelled';
    return Container(
      padding: EdgeInsets.all(12.w),
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
              Expanded(
                child: Text(
                  _textOf(contest['name']),
                  style: _value().copyWith(fontSize: 14.sp),
                ),
              ),
              if (status.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    status,
                    style: _label().copyWith(color: AppColors.primary),
                  ),
                ),
            ],
          ),
          if (_textOf(contest['tagline']).isNotEmpty) ...[
            SizedBox(height: 2.h),
            Text(_textOf(contest['tagline']), style: _label()),
          ],
          SizedBox(height: 8.h),
          Row(
            children: [
              _Stat(
                label: TranslationUtils.tr('ib_contest_dates'),
                value:
                    '${_dateOf(contest['start_date'])} → ${_dateOf(contest['end_date'])}',
              ),
              _Stat(
                label: TranslationUtils.tr('ib_contest_participants'),
                value: _textOf(contest['max_participants']),
              ),
              _Stat(
                label: TranslationUtils.tr('ib_contest_starting_balance'),
                value: _textOf(contest['starting_balance']),
              ),
            ],
          ),
          if (id != null) ...[
            SizedBox(height: 4.h),
            Obx(() {
              final busy = c.busyIds.contains(id);
              return Wrap(
                spacing: 4.w,
                children: [
                  _Action(
                    icon: Icons.people_outline,
                    label: TranslationUtils.tr('ib_contest_enrollments'),
                    onTap: () => Get.to(
                      () => IbContestEnrollmentsScreen(
                        contestId: id,
                        title: _textOf(contest['name']),
                      ),
                    ),
                  ),
                  if (!isCancelled) ...[
                    _Action(
                      icon: Icons.edit_outlined,
                      label: TranslationUtils.tr('ib_contest_edit'),
                      onTap: () =>
                          Get.to(() => IbContestFormScreen(contest: contest)),
                    ),
                    _Action(
                      icon: Icons.savings_outlined,
                      label: TranslationUtils.tr('ib_contest_add_fund'),
                      onTap: busy ? null : () => _askPrizeFund(id),
                    ),
                    _Action(
                      icon: Icons.cancel_outlined,
                      label: TranslationUtils.tr('ib_contest_cancel'),
                      color: AppColors.error,
                      onTap: busy ? null : () => _confirmCancel(id),
                    ),
                  ],
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  void _confirmCancel(int id) {
    Get.dialog<void>(
      AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(TranslationUtils.tr('ib_contest_cancel_title'), style: _value()),
        content: Text(TranslationUtils.tr('ib_contest_cancel_message'), style: _label()),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(TranslationUtils.tr('ib_contest_keep')),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              _contestController().cancelContest(id);
            },
            child: Text(
              TranslationUtils.tr('ib_contest_cancel'),
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _askPrizeFund(int id) {
    final amountCtrl = TextEditingController();
    Get.dialog<void>(
      AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(TranslationUtils.tr('ib_contest_add_fund'), style: _value()),
        content: TextField(
          controller: amountCtrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            labelText: TranslationUtils.tr('ib_contest_amount'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(TranslationUtils.tr('ib_contest_keep')),
          ),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
              if (amount < 0.01) return;
              Get.back();
              _contestController().addPrizeFund(id, amount);
            },
            child: Text(TranslationUtils.tr('ib_contest_add_fund')),
          ),
        ],
      ),
    ).whenComplete(amountCtrl.dispose);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _label()),
          SizedBox(height: 2.h),
          Text(value.isEmpty ? '-' : value, style: _value().copyWith(fontSize: 12.sp)),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.primary;
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 6.w),
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 16.sp, color: tint),
      label: Text(label, style: _label().copyWith(color: tint, fontWeight: FontWeight.w600)),
    );
  }
}

/// Create (`ib/demo-contest/store`) or edit (`{id}/update`) a contest.
class IbContestFormScreen extends StatefulWidget {
  const IbContestFormScreen({super.key, this.contest});

  final Map<String, dynamic>? contest;

  @override
  State<IbContestFormScreen> createState() => _IbContestFormScreenState();
}

class _IbContestFormScreenState extends State<IbContestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _c = _contestController();

  late final _name = TextEditingController(text: _textOf(widget.contest?['name']));
  late final _tagline =
      TextEditingController(text: _textOf(widget.contest?['tagline']));
  late final _startingBalance = TextEditingController(
    text: _textOf(widget.contest?['starting_balance']).isEmpty
        ? '10000'
        : _textOf(widget.contest?['starting_balance']),
  );
  late final _minParticipants = TextEditingController(
    text: _textOf(widget.contest?['min_participants']).isEmpty
        ? '1'
        : _textOf(widget.contest?['min_participants']),
  );
  late final _maxParticipants =
      TextEditingController(text: _textOf(widget.contest?['max_participants']));
  late final _fee =
      TextEditingController(text: _textOf(widget.contest?['enrollment_fee']));
  late final _adminShare = TextEditingController(
    text: _textOf(widget.contest?['ib_admin_share_percent']).isEmpty
        ? '20'
        : _textOf(widget.contest?['ib_admin_share_percent']),
  );

  late String _startDate = _dateOf(widget.contest?['start_date']);
  late String _endDate = _dateOf(widget.contest?['end_date']);
  late String _registrationCloses =
      _dateOf(widget.contest?['registration_closes']);
  late String _enrollmentType =
      _textOf(widget.contest?['enrollment_type']).isEmpty
          ? 'free'
          : _textOf(widget.contest?['enrollment_type']);
  late String _prizePoolType =
      _textOf(widget.contest?['prize_pool_type']).isEmpty
          ? 'fixed'
          : _textOf(widget.contest?['prize_pool_type']);
  late final Set<int> _instrumentIds = {
    for (final v in (widget.contest?['instruments'] is List
        ? widget.contest!['instruments'] as List
        : const []))
      if (_intOf(v is Map ? v['id'] : v) != null) _intOf(v is Map ? v['id'] : v)!,
  };
  String? _dateError;

  int? get _contestId => _intOf(widget.contest?['id']);

  @override
  void initState() {
    super.initState();
    _c.loadInstruments();
  }

  @override
  void dispose() {
    for (final ctrl in [
      _name,
      _tagline,
      _startingBalance,
      _minParticipants,
      _maxParticipants,
      _fee,
      _adminShare,
    ]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(String current, ValueChanged<String> onPicked) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(current) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    final y = picked.year.toString().padLeft(4, '0');
    final m = picked.month.toString().padLeft(2, '0');
    final d = picked.day.toString().padLeft(2, '0');
    setState(() {
      onPicked('$y-$m-$d');
      _dateError = null;
    });
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty)
      ? TranslationUtils.tr('ib_contest_required')
      : null;

  String? _minNumber(String? v, num min) {
    final n = num.tryParse(v?.trim() ?? '');
    if (n == null || n < min) {
      return TranslationUtils.trArgs('ib_contest_min_value', {'min': '$min'});
    }
    return null;
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    final datesOk = _startDate.isNotEmpty &&
        _endDate.isNotEmpty &&
        _endDate.compareTo(_startDate) >= 0;
    setState(() {
      _dateError = datesOk ? null : TranslationUtils.tr('ib_contest_dates_invalid');
    });
    if (!formOk || !datesOk) return;

    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'tagline': _tagline.text.trim(),
      'start_date': _startDate,
      'end_date': _endDate,
      if (_registrationCloses.isNotEmpty) 'registration_closes': _registrationCloses,
      'starting_balance': num.parse(_startingBalance.text.trim()),
      'min_participants': int.parse(_minParticipants.text.trim()),
      'max_participants': int.parse(_maxParticipants.text.trim()),
      // Not editable in the app; keep what the contest already has.
      'ranking_by': _textOf(widget.contest?['ranking_by']).isEmpty
          ? 'profit_percent'
          : _textOf(widget.contest?['ranking_by']),
      'timezone': _textOf(widget.contest?['timezone']).isEmpty
          ? 'UTC'
          : _textOf(widget.contest?['timezone']),
      'enrollment_type': _enrollmentType,
      if (_enrollmentType == 'paid')
        'enrollment_fee': num.tryParse(_fee.text.trim()) ?? 0,
      'prize_pool_type': _prizePoolType,
      'ib_admin_share_percent': num.parse(_adminShare.text.trim()),
      if (_instrumentIds.isNotEmpty) 'instruments': _instrumentIds.toList(),
    };
    final ok = await _c.saveContest(payload, id: _contestId);
    if (ok && mounted) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        backgroundColor: AppColors.scaffold,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const AppBackButton(),
        centerTitle: true,
        title: Text(
          TranslationUtils.tr(
            _contestId == null ? 'ib_contest_create' : 'ib_contest_edit',
          ),
          style: AppTextStyles.screenTitle,
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
            children: [
              _field(_name, 'ib_contest_name', validator: _required),
              _field(_tagline, 'ib_contest_tagline'),
              _dateTile('ib_contest_start_date', _startDate,
                  (v) => _startDate = v),
              _dateTile('ib_contest_end_date', _endDate, (v) => _endDate = v),
              _dateTile('ib_contest_registration_closes', _registrationCloses,
                  (v) => _registrationCloses = v),
              if (_dateError != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Text(
                    _dateError!,
                    style: _label().copyWith(color: AppColors.error),
                  ),
                ),
              _field(
                _startingBalance,
                'ib_contest_starting_balance',
                number: true,
                validator: (v) => _minNumber(v, 10),
              ),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _minParticipants,
                      'ib_contest_min_participants',
                      number: true,
                      validator: (v) => _minNumber(v, 1),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _field(
                      _maxParticipants,
                      'ib_contest_max_participants',
                      number: true,
                      validator: (v) {
                        final err = _minNumber(v, 1);
                        if (err != null) return err;
                        final min = int.tryParse(_minParticipants.text.trim()) ?? 1;
                        return int.parse(v!.trim()) < min
                            ? TranslationUtils.trArgs(
                                'ib_contest_min_value', {'min': '$min'})
                            : null;
                      },
                    ),
                  ),
                ],
              ),
              _choice(
                'ib_contest_enrollment_type',
                const {'free': 'ib_contest_free', 'paid': 'ib_contest_paid'},
                _enrollmentType,
                (v) => _enrollmentType = v,
              ),
              if (_enrollmentType == 'paid')
                _field(
                  _fee,
                  'ib_contest_enrollment_fee',
                  number: true,
                  validator: (v) => _minNumber(v, 0),
                ),
              _choice(
                'ib_contest_prize_pool_type',
                const {
                  'fixed': 'ib_contest_fixed',
                  'percentage': 'ib_contest_percentage',
                },
                _prizePoolType,
                (v) => _prizePoolType = v,
              ),
              _field(
                _adminShare,
                'ib_contest_admin_share',
                number: true,
                validator: (v) {
                  final err = _minNumber(v, 20);
                  if (err != null) return err;
                  return num.parse(v!.trim()) > 100
                      ? TranslationUtils.tr('ib_contest_max_100')
                      : null;
                },
              ),
              _instrumentPicker(),
              SizedBox(height: 16.h),
              Obx(() {
                final saving = _c.isSaving.value;
                return SizedBox(
                  height: 46.h,
                  child: ElevatedButton(
                    onPressed: saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.whiteColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: saving
                        ? SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.whiteColor,
                            ),
                          )
                        : Text(TranslationUtils.tr('ib_contest_submit')),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String labelKey, {
    bool number = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: TextFormField(
        controller: ctrl,
        validator: validator,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: number
            ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
            : null,
        style: _value(),
        decoration: InputDecoration(
          labelText: TranslationUtils.tr(labelKey),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
        ),
      ),
    );
  }

  Widget _dateTile(String labelKey, String value, ValueChanged<String> onPicked) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: InkWell(
        onTap: () => _pickDate(value, onPicked),
        borderRadius: BorderRadius.circular(10.r),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: TranslationUtils.tr(labelKey),
            isDense: true,
            suffixIcon: Icon(Icons.calendar_today_outlined, size: 16.sp),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
          ),
          child: Text(value.isEmpty ? '-' : value, style: _value()),
        ),
      ),
    );
  }

  Widget _choice(
    String labelKey,
    Map<String, String> options,
    String selected,
    ValueChanged<String> onSelected,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(TranslationUtils.tr(labelKey), style: _label()),
          SizedBox(height: 4.h),
          Wrap(
            spacing: 8.w,
            children: [
              for (final entry in options.entries)
                ChoiceChip(
                  label: Text(TranslationUtils.tr(entry.value)),
                  selected: selected == entry.key,
                  onSelected: (_) => setState(() => onSelected(entry.key)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _instrumentPicker() {
    return Obx(() {
      final symbols = _c.instrumentSymbols;
      if (symbols.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(TranslationUtils.tr('ib_contest_instruments'), style: _label()),
          SizedBox(height: 2.h),
          Text(TranslationUtils.tr('ib_contest_instruments_hint'), style: _label()),
          SizedBox(height: 6.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: [
              for (final s in symbols)
                if (_intOf(s['id']) != null)
                  FilterChip(
                    label: Text(_textOf(s['symbol_name'])),
                    selected: _instrumentIds.contains(_intOf(s['id'])),
                    onSelected: (on) => setState(() {
                      final id = _intOf(s['id'])!;
                      on ? _instrumentIds.add(id) : _instrumentIds.remove(id);
                    }),
                  ),
            ],
          ),
        ],
      );
    });
  }
}

/// Enrollments of one contest (`{id}/enrollments`) with approve / reject.
class IbContestEnrollmentsScreen extends StatefulWidget {
  const IbContestEnrollmentsScreen({
    super.key,
    required this.contestId,
    required this.title,
  });

  final int contestId;
  final String title;

  @override
  State<IbContestEnrollmentsScreen> createState() =>
      _IbContestEnrollmentsScreenState();
}

class _IbContestEnrollmentsScreenState
    extends State<IbContestEnrollmentsScreen> {
  final _c = _contestController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _c.loadEnrollments(widget.contestId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        backgroundColor: AppColors.scaffold,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const AppBackButton(),
        centerTitle: true,
        title: Text(
          widget.title.isEmpty
              ? TranslationUtils.tr('ib_contest_enrollments')
              : widget.title,
          style: AppTextStyles.screenTitle,
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          if (_c.isEnrollmentsLoading.value) {
            return const Center(child: CommonLoadingWidget());
          }
          if (_c.enrollments.isEmpty) {
            return _Message(text: TranslationUtils.tr('ib_contest_no_enrollments'));
          }
          return RefreshIndicator(
            onRefresh: () => _c.loadEnrollments(widget.contestId),
            child: ListView.separated(
              padding: EdgeInsets.all(16.w),
              itemCount: _c.enrollments.length,
              separatorBuilder: (_, __) => SizedBox(height: 10.h),
              itemBuilder: (_, i) => _enrollmentCard(_c.enrollments[i]),
            ),
          );
        }),
      ),
    );
  }

  Widget _enrollmentCard(Map<String, dynamic> e) {
    final id = _intOf(e['id']);
    final user = e['user'] is Map ? e['user'] as Map : const {};
    final name =
        '${_textOf(user['first_name'])} ${_textOf(user['last_name'])}'.trim();
    final status = _textOf(e['enrollment_status']);
    final isPending = status.toLowerCase() == 'pending';
    return Container(
      padding: EdgeInsets.all(12.w),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? '-' : name, style: _value()),
                    Text(_textOf(user['email']), style: _label()),
                  ],
                ),
              ),
              Text(status, style: _label().copyWith(color: AppColors.primary)),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              _Stat(
                label: TranslationUtils.tr('ib_contest_account'),
                value: _textOf(e['demo_account_number']),
              ),
              _Stat(
                label: TranslationUtils.tr('ib_contest_equity'),
                value: _textOf(e['current_equity']),
              ),
              _Stat(
                label: TranslationUtils.tr('ib_contest_return'),
                value: '${_textOf(e['return_percent'])}%',
              ),
            ],
          ),
          if (_textOf(e['rejection_reason']).isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(_textOf(e['rejection_reason']), style: _label()),
          ],
          if (id != null && isPending)
            Obx(() {
              final busy = _c.busyIds.contains(id);
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _Action(
                    icon: Icons.close,
                    label: TranslationUtils.tr('ib_contest_reject'),
                    color: AppColors.error,
                    onTap: busy ? null : () => _askReject(id),
                  ),
                  _Action(
                    icon: Icons.check,
                    label: TranslationUtils.tr('ib_contest_approve'),
                    onTap: busy
                        ? null
                        : () => _c.approveEnrollment(id, widget.contestId),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  void _askReject(int enrollmentId) {
    final reasonCtrl = TextEditingController();
    Get.dialog<void>(
      AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(TranslationUtils.tr('ib_contest_reject'), style: _value()),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: TranslationUtils.tr('ib_contest_reject_reason'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(TranslationUtils.tr('ib_contest_keep')),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              _c.rejectEnrollment(
                enrollmentId,
                widget.contestId,
                reasonCtrl.text.trim(),
              );
            },
            child: Text(
              TranslationUtils.tr('ib_contest_reject'),
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    ).whenComplete(reasonCtrl.dispose);
  }
}
