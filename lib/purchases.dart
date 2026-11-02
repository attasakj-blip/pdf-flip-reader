import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';

/// Product ids in Play Console (Monetize › In-app products). Both are
/// one-time purchases.
const clearId = 'pagelume_clear'; // removes ads
const goldId = 'pagelume_gold'; // every Gold tool, and no ads

/// Tools that need Pagelume Gold. Each can be tried [freeTries] times first.
enum GoldFeature { sign, text, shapes, deletePages, translateDoc, ocr, flipStyle, ambient }

const freeTries = 3;

/// Page-turn looks (FlipStyle indexes) free to everyone: curl, slide, fade.
const freeFlipStyles = {0, 2, 3};

/// Background sounds (indexes) free to everyone: the first three.
const freeAmbient = {0, 1, 2};

/// What the person has bought. Only the Android app sells anything for now;
/// on other systems everything is open and there are no ads to remove.
class Purchases extends ChangeNotifier {
  Purchases._(this._prefs, {required this.selling});

  /// Until [load] runs (and in tests) nothing is sold and everything is open.
  static Purchases instance = Purchases.free();

  /// Nothing sold, everything open.
  Purchases.free() : this._(null, selling: false);

  /// Sets up [instance]. [selling] defaults to Android.
  static Future<Purchases> load({bool? selling}) async {
    final p = Purchases._(await SharedPreferences.getInstance(), selling: selling ?? Platform.isAndroid);
    instance = p;
    return p;
  }

  final SharedPreferences? _prefs;
  final bool selling;

  /// Prices as Google Play shows them, once loaded.
  final products = <String, ProductDetails>{};
  bool storeReady = false;

  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Cached on the phone so it works offline; checked with Google Play on
  /// every start.
  bool get hasGold => !selling || (_prefs?.getBool('owns_$goldId') ?? false);
  bool get hasClear => _prefs?.getBool('owns_$clearId') ?? false;
  bool get adsOff => selling && (hasGold || hasClear);

  bool flipStyleOk(int i) => hasGold || freeFlipStyles.contains(i);
  bool ambientOk(int i) => i < 0 || hasGold || freeAmbient.contains(i);

  int triesLeft(GoldFeature f) => (freeTries - (_prefs?.getInt('tries_${f.name}') ?? 0)).clamp(0, freeTries);

  void _useTry(GoldFeature f) => _prefs?.setInt('tries_${f.name}', freeTries - triesLeft(f) + 1);

  void _own(String id, bool v) {
    if ((_prefs?.getBool('owns_$id') ?? false) == v) return;
    _prefs?.setBool('owns_$id', v);
    notifyListeners();
  }

  /// For tests.
  @visibleForTesting
  void grant(String id, [bool v = true]) => _own(id, v);

  /// Connects to Google Play: loads prices, listens for purchases (also ones
  /// finished later, such as cash payments at a shop), and re-checks what is
  /// owned so refunds are taken back.
  Future<void> start() async {
    if (!selling) return;
    try {
      final iap = InAppPurchase.instance;
      _sub = iap.purchaseStream.listen(_onPurchases, onError: (Object e) => debugPrint('purchase error: $e'));
      if (!await iap.isAvailable()) return;
      final r = await iap.queryProductDetails({clearId, goldId});
      for (final p in r.productDetails) {
        products[p.id] = p;
      }
      storeReady = true;
      notifyListeners();
      await _checkOwned();
    } catch (e) {
      debugPrint('store unavailable: $e');
    }
  }

  /// Asks Google Play for everything this account owns.
  Future<bool> _checkOwned() async {
    final add = InAppPurchase.instance.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final r = await add.queryPastPurchases();
    if (r.error != null) return false;
    final owned = <String>{};
    for (final p in r.pastPurchases) {
      if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
        owned.add(p.productID);
        if (p.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(p);
      }
    }
    _own(goldId, owned.contains(goldId));
    _own(clearId, owned.contains(clearId));
    return true;
  }

  /// Shown in a snack bar by [showPaywall]'s caller.
  final messages = StreamController<String Function(S)>.broadcast();

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _own(p.productID, true);
          messages.add((s) => p.productID == goldId ? s.thanksGold : s.thanksClear);
        case PurchaseStatus.pending:
          messages.add((s) => s.purchasePending);
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          break;
      }
      // Google refunds purchases that are not acknowledged within 3 days.
      if (p.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(p);
    }
  }

  Future<void> buy(String id) async {
    final p = products[id];
    if (p == null) return;
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
  }

  /// Re-checks with Google Play. Returns false when Play cannot be reached.
  Future<bool> restore() async {
    if (!selling) return true;
    try {
      return await _checkOwned();
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    messages.close();
    super.dispose();
  }
}

/// Lets a Gold tool go ahead: always with Gold, otherwise while free tries
/// last (one is used now, and a note says how many are left), otherwise
/// after the person buys Gold.
Future<bool> requireGold(BuildContext context, GoldFeature f) async {
  final p = Purchases.instance;
  if (p.hasGold) return true;
  final left = p.triesLeft(f);
  if (left > 0 && f != GoldFeature.flipStyle && f != GoldFeature.ambient) {
    p._useTry(f);
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(S.of(context).goldTryLeft(left - 1)),
          action: SnackBarAction(label: 'Gold', onPressed: () => showPaywall(context)),
        ),
      );
    return true;
  }
  await showPaywall(context, locked: true);
  return p.hasGold;
}

/// The Gold and Clear offer, with restore.
Future<void> showPaywall(BuildContext context, {bool locked = false}) async {
  final p = Purchases.instance;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final sub = p.messages.stream.listen((m) {
    if (context.mounted) messenger?.showSnackBar(SnackBar(content: Text(m(S.of(context)))));
  });
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => ListenableBuilder(
      listenable: p,
      builder: (ctx, _) {
        final s = S.of(ctx);
        final gold = p.products[goldId];
        final clear = p.products[clearId];
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.workspace_premium, size: 48, color: Color(0xFFFFC94D)),
                const SizedBox(height: 8),
                Text('Pagelume Gold', textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.headlineSmall),
                const SizedBox(height: 8),
                if (p.hasGold)
                  Text(s.goldOwned, textAlign: TextAlign.center)
                else ...[
                  if (locked) Text(s.goldLocked, textAlign: TextAlign.center),
                  Text(s.goldPitch, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(s.goldFeatures, textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  if (!p.storeReady || gold == null)
                    Text(s.storeUnavailable, textAlign: TextAlign.center)
                  else
                    FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      icon: const Icon(Icons.workspace_premium),
                      label: Text(s.buyGold(gold.price)),
                      onPressed: () => p.buy(goldId),
                    ),
                  if (p.storeReady && clear != null && !p.hasClear) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () => p.buy(clearId),
                      child: Text(s.buyClear(clear.price)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      final ok = await p.restore();
                      if (!ctx.mounted) return;
                      final msg = !ok
                          ? s.storeUnavailable
                          : p.hasGold
                          ? s.thanksGold
                          : p.hasClear
                          ? s.thanksClear
                          : s.restoredNone;
                      messenger?.showSnackBar(SnackBar(content: Text(msg)));
                    },
                    child: Text(s.restorePurchases),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
  unawaited(sub.cancel());
}
