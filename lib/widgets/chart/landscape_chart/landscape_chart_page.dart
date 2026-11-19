import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureType, lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/precision_helper.dart';

const _swingDuration = Duration(milliseconds: 380);

// Notifiers whose page is on its way up, so a double tap opens it once.
final _opening = <ValueNotifier<bool>>{};

/// Opens the landscape chart page above the bottom nav.
///
/// The device is never rotated. A real orientation change makes Android
/// resize the window, which shows black for a few frames and blinks again
/// when the system bars hide. Instead the page is laid out landscape inside a
/// [RotatedBox] and swings into place with a rotate + scale animation.
///
/// [isOpen] is true while the page holds the chart. The portrait layout must
/// hide its chart then, because the same keyed chart instance moves into the
/// page — building it in both places throws "Duplicate GlobalKey".
///
/// The chart is a WebView, and a WebView paints black wherever it has not
/// redrawn yet while it turns or resizes. So it only moves in once the page
/// has finished swinging (and stays covered until it has redrawn), and the
/// page gives it back before it swings out.
Future<void> openLandscapeChart(
  BuildContext context, {
  required ValueNotifier<bool> isOpen,
  required WidgetBuilder pageBuilder,
}) async {
  if (isOpen.value || !_opening.add(isOpen)) return;
  FocusScope.of(context).unfocus();

  final route = PageRouteBuilder<void>(
    opaque: false,
    transitionDuration: _swingDuration,
    reverseTransitionDuration: _swingDuration,
    pageBuilder: (_, __, ___) => _LandscapeViewport(builder: pageBuilder),
    transitionsBuilder:
        (_, animation, __, child) =>
            _LandscapeSwing(animation: animation, child: child),
  );

  void onStatus(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.completed:
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        // The page stands still now; until here the portrait screen keeps
        // showing the chart behind it.
        if (context.mounted) isOpen.value = true;
      case AnimationStatus.reverse:
        restorePortraitOrientation();
      case AnimationStatus.dismissed:
      case AnimationStatus.forward:
        break;
    }
  }

  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(navigator.push(route));
  route.animation!.addStatusListener(onStatus);

  await route.completed;
  _opening.remove(isOpen);
  route.animation?.removeStatusListener(onStatus);
  // Removed without the reverse animation, e.g. the stack was reset.
  if (context.mounted && isOpen.value) isOpen.value = false;
  await restorePortraitOrientation();
}

/// Puts the system bars back and re-applies the app's portrait lock from
/// main.dart. The app never sets a system UI mode at startup, so "all
/// overlays visible" is the mode to go back to.
Future<void> restorePortraitOrientation() async {
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );
}

/// Lays the page out landscape on a portrait screen: turned a quarter
/// clockwise, with MediaQuery swapped to match so the page sees a landscape
/// size and system paddings on the right edges.
class _LandscapeViewport extends StatelessWidget {
  const _LandscapeViewport({required this.builder});

  final WidgetBuilder builder;

  // Clockwise turn: the page's left edge sits at the screen top, its top at
  // the screen right, its right at the screen bottom, its bottom at the left.
  static EdgeInsets _turn(EdgeInsets insets) => EdgeInsets.fromLTRB(
    insets.top,
    insets.right,
    insets.bottom,
    insets.left,
  );

  // Same turn for a rect in portrait screen coordinates: a portrait point
  // (x, y) lands at (y, portraitWidth - x) on the page.
  static Rect _turnRect(Rect rect, double portraitWidth) => Rect.fromLTRB(
    rect.top,
    portraitWidth - rect.right,
    rect.bottom,
    portraitWidth - rect.left,
  );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return RotatedBox(
      quarterTurns: 1,
      child: MediaQuery(
        data: media.copyWith(
          size: media.size.flipped,
          // Lets the page see where the camera cutout really is, not just
          // which edge it is on.
          displayFeatures: [
            for (final feature in media.displayFeatures)
              DisplayFeature(
                bounds: _turnRect(feature.bounds, media.size.width),
                type: feature.type,
                state: feature.state,
              ),
          ],
          padding: _turn(media.padding),
          viewPadding: _turn(media.viewPadding),
          systemGestureInsets: _turn(media.systemGestureInsets),
          // The page has no text fields, and a keyboard would open in
          // portrait anyway.
          viewInsets: EdgeInsets.zero,
        ),
        child: Builder(builder: builder),
      ),
    );
  }
}

/// At 0 the landscape page lies flat, shrunk to the screen width; at 1 it
/// has turned a quarter clockwise and fills the screen. Runs backwards on
/// close.
class _LandscapeSwing extends StatelessWidget {
  const _LandscapeSwing({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  static const _fade = Interval(0, 0.3, curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final startScale = size.width / size.height;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final turn = Curves.easeInOutCubic.transform(animation.value);
        final opacity = _fade.transform(animation.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: opacity,
              child: ColoredBox(color: AppColors.tradeBackgroundCenterColor),
            ),
            Opacity(
              opacity: opacity,
              child: Transform.rotate(
                angle: -(1 - turn) * math.pi / 2,
                child: Transform.scale(
                  scale: lerpDouble(startScale, 1, turn)!,
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Fullscreen landscape chart with a compact trade bar along the top.
///
/// Every brand screen supplies its own chart, lot field, prices and order
/// handlers, so SELL/BUY run exactly the same logic as in portrait.
///
/// Sizes are plain logical pixels: ScreenUtil's .w/.h/.sp scale off the
/// portrait design size and distort badly once the device is rotated.
class LandscapeChartPage extends StatefulWidget {
  const LandscapeChartPage({
    super.key,
    required this.isOpen,
    required this.chartBuilder,
    required this.currentSymbol,
    required this.onSymbolChanged,
    required this.volumeController,
    required this.minLot,
    required this.maxLot,
    this.bid,
    this.ask,
    this.spread,
    this.onSell,
    this.onBuy,
    this.tradeButtonsBuilder,
    this.displaySymbol = stripSymbolSuffix,
    this.symbolListenable,
    this.symbolStream,
    this.priceStream,
    this.onVolumeChanged,
    this.isPlacingOrder,
    this.overlay,
  }) : assert(
         tradeButtonsBuilder != null ||
             (bid != null &&
                 ask != null &&
                 spread != null &&
                 onSell != null &&
                 onBuy != null),
         'Pass tradeButtonsBuilder, or bid/ask/spread with onSell/onBuy.',
       );

  /// True while the page holds the chart; [openLandscapeChart] sets it back
  /// to false once the close animation has finished.
  final ValueNotifier<bool> isOpen;
  final WidgetBuilder chartBuilder;

  final String Function() currentSymbol;
  final ValueChanged<String> onSymbolChanged;
  final String Function(String symbol) displaySymbol;

  /// Either source rebuilds the page when the symbol changes. This route is
  /// not rebuilt by the owning screen's setState.
  final Listenable? symbolListenable;
  final Stream<dynamic>? symbolStream;

  final TextEditingController volumeController;
  final double Function() minLot;
  final double Function() maxLot;
  final ValueChanged<double>? onVolumeChanged;

  /// Each event refreshes the bid/ask/spread readout.
  final Stream<dynamic>? priceStream;
  final String Function()? bid;
  final String Function()? ask;
  final String Function()? spread;

  final VoidCallback? onSell;
  final VoidCallback? onBuy;
  final bool Function()? isPlacingOrder;

  /// Replaces the default SELL / lot stepper / BUY row, for screens whose
  /// order handlers live inside their own trade buttons. Place the given
  /// lot stepper between SELL and BUY. Rebuilt on [priceStream].
  final Widget Function(BuildContext context, Widget lotStepper)?
  tradeButtonsBuilder;

  /// Drawn above the page, e.g. the one-click trade notifications.
  final Widget? overlay;

  static String stripSymbolSuffix(String symbol) {
    final dot = symbol.lastIndexOf('.');
    return dot > 0 ? symbol.substring(0, dot) : symbol;
  }

  @override
  State<LandscapeChartPage> createState() => _LandscapeChartPageState();
}

class _LandscapeChartPageState extends State<LandscapeChartPage> {
  static const _pickerSlide = Duration(milliseconds: 220);
  // Time the WebView gets to lay out and redraw at its new size before the
  // cover lifts.
  static const _redrawDelay = Duration(milliseconds: 300);
  static const _coverFade = Duration(milliseconds: 250);
  // Time the portrait screen gets to redraw the chart, still hidden behind
  // this page, before the page swings out.
  static const _handBackDelay = Duration(milliseconds: 150);
  // Keeps the top bar's end tiles clear of the screen's rounded corners,
  // which Flutter reports no inset for.
  static const _cornerClearance = 24.0;
  static const _barHeight = 56.0;

  StreamSubscription<dynamic>? _symbolSubscription;
  bool _pickerOpen = false;
  bool _chartRevealed = false;
  bool _closing = false;
  Timer? _revealTimer;

  LanguageService get _lang => Get.find<LanguageService>();

  @override
  void initState() {
    super.initState();
    widget.symbolListenable?.addListener(_onSymbolChanged);
    _symbolSubscription = widget.symbolStream?.listen((_) => _onSymbolChanged());
    widget.isOpen.addListener(_onIsOpenChanged);
    _onIsOpenChanged();
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    widget.isOpen.removeListener(_onIsOpenChanged);
    widget.symbolListenable?.removeListener(_onSymbolChanged);
    _symbolSubscription?.cancel();
    super.dispose();
  }

  void _onSymbolChanged() {
    if (mounted) setState(() {});
  }

  void _onIsOpenChanged() {
    _revealTimer?.cancel();
    if (!widget.isOpen.value || _closing) return;
    _revealTimer = Timer(_redrawDelay, () {
      if (mounted) setState(() => _chartRevealed = true);
    });
  }

  // Cover the chart, hand it back to the portrait screen, then swing out, so
  // the WebView never turns or resizes while it is visible.
  Future<void> _close() async {
    if (_closing) return;
    _revealTimer?.cancel();
    setState(() {
      _closing = true;
      _chartRevealed = false;
    });
    await Future<void>.delayed(_coverFade);
    if (!mounted) return;
    widget.isOpen.value = false;
    await Future<void>.delayed(_handBackDelay);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Every close goes through _close, which pops once the chart is back.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Back closes the symbol picker first, then the page.
        if (_pickerOpen) {
          _closePicker();
        } else {
          _close();
        }
      },
      child: Scaffold(
        // Theme base, so the strip left beside the camera cutout blends with
        // the top bar instead of showing as a grey band.
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(context),
                Expanded(
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: widget.isOpen,
                          builder:
                              (context, isOpen, _) =>
                                  isOpen
                                      ? widget.chartBuilder(context)
                                      : const SizedBox.shrink(),
                        ),
                        IgnorePointer(
                          child: AnimatedOpacity(
                            key: const ValueKey('landscape-chart-cover'),
                            opacity: _chartRevealed ? 0 : 1,
                            duration: _coverFade,
                            curve: Curves.easeInOut,
                            child: ColoredBox(
                              color: AppColors.tradeBackgroundCenterColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (widget.overlay != null) widget.overlay!,
            ..._buildPickerLayers(context),
          ],
        ),
      ),
    );
  }

  // Left to right: minimize, symbol, SELL, − lot +, BUY. The chart gets the
  // full width below.
  Widget _buildTopBar(BuildContext context) {
    // The camera cutout's inset covers its whole edge, but the hole itself
    // usually sits mid-edge, below the bar. When the reported cutouts all
    // miss the bar, only the rounded corners need clearing. Otherwise (or
    // when the platform reports no cutout shape) use the larger inset on
    // both ends so nothing is cut and the bar stays balanced.
    final media = MediaQuery.of(context);
    final barBand = Rect.fromLTWH(0, 0, media.size.width, _barHeight);
    final cutouts = media.displayFeatures.where(
      (feature) => feature.type == DisplayFeatureType.cutout,
    );
    final cutoutClearOfBar =
        cutouts.isNotEmpty &&
        !cutouts.any((cutout) => cutout.bounds.overlaps(barBand));
    final sideInset =
        cutoutClearOfBar
            ? _cornerClearance
            : math.max(
              _cornerClearance,
              math.max(media.padding.left, media.padding.right),
            );
    final theme = Theme.of(context);
    return Container(
      height: _barHeight,
      padding: EdgeInsets.fromLTRB(sideInset, 8, sideInset, 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        // border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.of(context).maybePop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            ),
            icon: Icon(
              Icons.fullscreen_exit_rounded,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 132, child: _buildSymbolSwitch(context)),
          const SizedBox(width: 8),
          Expanded(
            child: StreamBuilder<dynamic>(
              stream: widget.priceStream,
              builder: (context, _) {
                final lotStepper = _buildLotStepper();
                return widget.tradeButtonsBuilder?.call(context, lotStepper) ??
                    _buildTradeButtons(lotStepper);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymbolSwitch(BuildContext context) {
    return Semantics(
      button: true,
      label: _lang.tr('chart_landscape_change_symbol'),
      child: InkWell(
        onTap: _openPicker,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.displaySymbol(widget.currentSymbol()),
                    maxLines: 1,
                    style: AppTextStyles.label.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPicker() => setState(() => _pickerOpen = true);

  void _closePicker() => setState(() => _pickerOpen = false);

  // Own compact picker, drawn inside the page: a dialog route would sit
  // outside the RotatedBox and open in portrait. No search field, because a
  // keyboard would open sideways. Same favourites source as the portrait one.
  List<Widget> _buildPickerLayers(BuildContext context) {
    return [
      Positioned.fill(
        child: IgnorePointer(
          ignoring: !_pickerOpen,
          child: AnimatedOpacity(
            opacity: _pickerOpen ? 1 : 0,
            duration: _pickerSlide,
            child: Semantics(
              button: true,
              label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
              child: GestureDetector(
                onTap: _closePicker,
                child: const ColoredBox(color: Colors.black54),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        top: 0,
        right: 0,
        bottom: 0,
        width: 300,
        child: IgnorePointer(
          ignoring: !_pickerOpen,
          child: AnimatedSlide(
            offset: _pickerOpen ? Offset.zero : const Offset(1, 0),
            duration: _pickerSlide,
            curve: Curves.easeOutCubic,
            child: Material(
              color: AppColors.tradeBackgroundCenterColor,
              child: SafeArea(
                left: false,
                child: Column(
                  children: [
                    _buildPickerHeader(context),
                    Expanded(child: _buildPickerList()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildPickerHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _lang.tr('chart_landscape_symbols'),
              style: AppTextStyles.label.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: _closePicker,
            icon: Icon(
              Icons.close_rounded,
              size: 20,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerList() {
    if (!Get.isRegistered<InstrumentsController>()) {
      return _buildPickerMessage('chart_landscape_no_favourites');
    }
    final controller = Get.find<InstrumentsController>();

    return Obx(() {
      final seen = <String>{};
      final symbols = <String>[];
      for (final instrument in controller.instruments) {
        final name = widget.displaySymbol(instrument.symbol);
        if (seen.add(name.toUpperCase())) symbols.add(instrument.symbol);
      }

      if (controller.isLoadingFavorites.value && controller.instruments.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (symbols.isEmpty) {
        return _buildPickerMessage('chart_landscape_no_favourites');
      }

      final currentName = widget.displaySymbol(widget.currentSymbol());
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: symbols.length,
        itemBuilder: (_, index) {
          final symbol = symbols[index];
          final name = widget.displaySymbol(symbol);
          final isSelected = name == currentName;
          return InkWell(
            onTap: () {
              _closePicker();
              if (!isSelected) widget.onSymbolChanged(symbol);
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : null,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  _SymbolFlag(name: name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.input.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildPickerMessage(String key) {
    return Center(
      child: Text(
        _lang.tr(key),
        style: AppTextStyles.label.copyWith(fontSize: 13),
      ),
    );
  }

  void _setVolume(double value) {
    widget.volumeController.text = PrecisionHelper.formatVolume(value);
    widget.onVolumeChanged?.call(value);
  }

  void _stepVolume(double delta) {
    final current = PrecisionHelper.parseLotInput(
      widget.volumeController.text,
      widget.minLot(),
      widget.maxLot(),
    );
    _setVolume(
      PrecisionHelper.clamp(current + delta, widget.minLot(), widget.maxLot()),
    );
  }

  // The lot is display only: the device stays in portrait, so a keyboard
  // would open sideways across the rotated page. The spread sits under it,
  // between SELL and BUY.
  Widget _buildLotStepper() {
    final spread = widget.spread?.call();
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: AppColors.tradeBackgroundCenterColor,
        borderRadius: BorderRadius.circular(10),
        // Outlined like the symbol switch; the fill alone barely shows on
        // the bar's base background.
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LotStepButton(
            tooltip: _lang.tr('chart_landscape_decrease_lot'),
            icon: Icons.remove_rounded,
            onTap: () => _stepVolume(-0.01),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.volumeController,
                    builder:
                        (_, value, __) => Semantics(
                          label: _lang.tr('chart_landscape_lot'),
                          child: Text(
                            value.text.isEmpty
                                ? PrecisionHelper.formatVolume(widget.minLot())
                                : value.text,
                            maxLines: 1,
                            style: AppTextStyles.label.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                  ),
                  if (spread != null)
                    Text(
                      '${_lang.tr('chart_landscape_spread')} $spread',
                      maxLines: 1,
                      style: AppTextStyles.label.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
          _LotStepButton(
            tooltip: _lang.tr('chart_landscape_increase_lot'),
            icon: Icons.add_rounded,
            onTap: () => _stepVolume(0.01),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeButtons(Widget lotStepper) {
    final isPlacing = widget.isPlacingOrder?.call() ?? false;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LandscapeTradeTile(
            label: _lang.tr('general_sell').toUpperCase(),
            price: widget.bid!(),
            color: AppColors.error,
            dimmed: isPlacing,
            onTap: widget.onSell,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: lotStepper,
        ),
        Expanded(
          child: LandscapeTradeTile(
            label: _lang.tr('general_buy').toUpperCase(),
            price: widget.ask!(),
            color: AppColors.success,
            dimmed: isPlacing,
            onTap: widget.onBuy,
          ),
        ),
      ],
    );
  }
}

/// Portrait-side button that opens the landscape chart. [size] and [radius]
/// let each brand match its own row of icon buttons.
class FullscreenChartButton extends StatelessWidget {
  const FullscreenChartButton({
    super.key,
    required this.onTap,
    this.size = 44,
    this.radius = 7,
    this.backgroundColor,
    this.iconColor,
  });

  final VoidCallback onTap;
  final double size;
  final double radius;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: Get.find<LanguageService>().tr('chart_fullscreen'),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor ?? AppColors.cardBackGround,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Icon(
            Icons.fullscreen_rounded,
            size: size * 0.55,
            color: iconColor ?? AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Compact SELL/BUY tile for the landscape top bar. Leave [onTap] null when
/// the caller already wraps it in its own gesture handler.
class LandscapeTradeTile extends StatelessWidget {
  const LandscapeTradeTile({
    super.key,
    required this.label,
    required this.price,
    required this.color,
    this.dimmed = false,
    this.onTap,
  });

  final String label;
  final String price;
  final Color color;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label $price',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: dimmed ? 0.5 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            // Scale down rather than overflow when a narrow screen leaves the
            // tile less width than label + price need.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.button.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.onColoredBackground.withValues(
                        alpha: 0.85,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    price,
                    style: AppTextStyles.button.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onColoredBackground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// −/+ button of the landscape lot stepper. A plain InkWell keeps it at a
/// fixed 36px width; IconButton pads itself up to a 48px tap target.
class _LotStepButton extends StatelessWidget {
  const _LotStepButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 36,
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
      ),
    );
  }
}

/// Fixed-size flag; the screens' own flag helpers use ScreenUtil sizes.
class _SymbolFlag extends StatelessWidget {
  const _SymbolFlag({required this.name});

  final String name;

  static final Map<String, Future<bool>> _assetExists = {};

  static Future<bool> _exists(String path) {
    return _assetExists.putIfAbsent(path, () async {
      try {
        await rootBundle.load(path);
        return true;
      } catch (_) {
        return false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final path = 'assets/svg/flags/${name.toLowerCase()}.svg';
    return SizedBox(
      width: 28,
      height: 28,
      child: FutureBuilder<bool>(
        future: _exists(path),
        builder: (_, snapshot) {
          if (snapshot.data ?? false) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SvgPicture.asset(path, fit: BoxFit.cover),
            );
          }
          return Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              name.length < 2 ? name : name.substring(0, 2),
              style: AppTextStyles.label.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        },
      ),
    );
  }
}
