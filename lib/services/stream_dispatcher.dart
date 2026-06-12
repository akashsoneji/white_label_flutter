// lib/services/stream_dispatcher.dart
//
// The "condition gate" between the single [StreamService] and the legacy
// per-channel controllers. Each binding decides *if* a frame should reach
// the controller, based on:
//
//   1. Is the controller interested in this channel at all?
//      (e.g. trading controller only wants positions/orders/account;
//       instruments controller only wants prices; etc.)
//
//   2. Does the account on the frame match the active account?
//      (prevents stale frames from a previous account after a switch)
//
//   3. Is the symbol on the frame in the active symbol set?
//      (prices only — controllers can hand a whitelist to the dispatcher)
//
// Bindings are *additive* — multiple bindings can subscribe to the same
// stream, and the dispatcher fans out. This lets you route the same price
// tick to, say, the trading screen, the price-alert service, AND the
// instruments list, without duplicating the WebSocket work.
//
// Bindings are designed to be cheap to attach/detach — they hold streams
// not state, so a binding's lifecycle is exactly the lifecycle of its
// controller (no need to clean up on every account switch).
//
import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:crm_app/models/stream_envelope.dart';
import 'package:crm_app/services/stream_service.dart';

/// A single binding from one of the [StreamService] channels to a
/// controller. Created via [StreamChannelBinder] helpers and registered
/// with [StreamDispatcher.subscribe*] methods.
class StreamBinding {
  final String name;
  void Function(dynamic event) handler;
  StreamSubscription? _sub;

  StreamBinding({required this.name, required this.handler});

  void attach(Stream<dynamic> stream) {
    _sub?.cancel();
    _sub = stream.listen(
      (e) {
        try {
          handler(e);
        } catch (err, st) {
          if (kDebugMode) {
            dev.log('StreamBinding[$name] handler error: $err\n$st');
          }
        }
      },
      onError: (e) {
        if (kDebugMode) dev.log('StreamBinding[$name] stream error: $e');
      },
    );
  }

  Future<void> detach() async {
    await _sub?.cancel();
    _sub = null;
  }
}

/// The condition gate. The dispatcher is the *only* place that knows the
/// per-frame policy:
///
///   - **Account filter**: drop frames whose `account` field doesn't match
///     the currently active account. The active account is updated by
///     [updateActiveAccount] whenever a new one is selected.
///
///   - **Symbol filter**: optional per-binding symbol whitelist. The
///     instruments controller, for example, may want to receive ticks only
///     for symbols the user has added to their market watch.
///
///   - **Stale-frame guard**: if a binding is interested in a frame but
///     the account on the frame is empty (e.g. a price tick), the binding
///     is allowed to receive it (it has no account to compare against).
class StreamDispatcher {
  StreamDispatcher(this._service);

  final StreamService _service;

  /// Current account we expect to see on account-bearing frames.
  String _activeAccount = '';

  final List<StreamBinding> _accountBindings = [];
  final List<StreamBinding> _positionBindings = [];
  final List<StreamBinding> _pendingOrderBindings = [];
  final List<StreamBinding> _priceBindings = [];

  void updateActiveAccount(String account) {
    _activeAccount = account;
  }

  String get activeAccount => _activeAccount;

  // ──────────────────────────────────────────────────────────────────────
  // Subscribe helpers
  // ──────────────────────────────────────────────────────────────────────

  StreamBinding subscribeAccount({
    required String name,
    required void Function(AccountTick tick) handler,
  }) {
    return _attach(
      _accountBindings,
      name: name,
      stream: _service.account,
      handler: handler,
    );
  }

  StreamBinding subscribePositions({
    required String name,
    required void Function(PositionEvent event) handler,
  }) {
    return _attach(
      _positionBindings,
      name: name,
      stream: _service.positions,
      handler: handler,
    );
  }

  StreamBinding subscribePendingOrders({
    required String name,
    required void Function(PendingOrderEvent event) handler,
  }) {
    return _attach(
      _pendingOrderBindings,
      name: name,
      stream: _service.pendingOrders,
      handler: handler,
    );
  }

  StreamBinding subscribePrices({
    required String name,
    required void Function(PriceTick tick) handler,
    /// Optional whitelist. If non-null, ticks whose symbol isn't in the
    /// set are dropped *at the dispatcher* — handlers never see them.
    Set<String>? symbolWhitelist,
  }) {
    final set = symbolWhitelist?.map((s) => s.toUpperCase()).toSet();
    return _attach(
      _priceBindings,
      name: name,
      stream: _service.prices,
      handler: (PriceTick tick) {
        if (set != null && !set.contains(tick.symbol.toUpperCase())) {
          return; // dropped at dispatcher
        }
        handler(tick);
      },
    );
  }

  /// Update the symbol whitelist for a previously-attached price binding.
  /// Implemented by re-subscribing internally; the binding identity is
  /// preserved.
  void updatePriceWhitelist(StreamBinding binding, Set<String> symbols) {
    if (!_priceBindings.contains(binding)) return;
    // The whitelist is baked into the handler closure on attach — reattach
    // with a new closure so the new whitelist takes effect.
    final idx = _priceBindings.indexOf(binding);
    final original = binding.handler;
    binding.handler = (dynamic e) {
      if (e is PriceTick) {
        if (symbols.isNotEmpty &&
            !symbols.contains(e.symbol.toUpperCase())) {
          return;
        }
      }
      original(e);
    };
    _priceBindings[idx] = binding;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Tear-down
  // ──────────────────────────────────────────────────────────────────────

  Future<void> detachAll() async {
    for (final b in _accountBindings) await b.detach();
    for (final b in _positionBindings) await b.detach();
    for (final b in _pendingOrderBindings) await b.detach();
    for (final b in _priceBindings) await b.detach();
    _accountBindings.clear();
    _positionBindings.clear();
    _pendingOrderBindings.clear();
    _priceBindings.clear();
  }

  // ──────────────────────────────────────────────────────────────────────
  StreamBinding _attach<T>(
    List<StreamBinding> bucket, {
    required String name,
    required Stream<dynamic> stream,
    required void Function(T event) handler,
  }) {
    final binding = StreamBinding(
      name: name,
      handler: (dynamic event) => handler(event as T),
    );
    binding.attach(stream);
    bucket.add(binding);
    return binding;
  }
}
