import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';
import 'windows_store.dart';

/// Product ids in Play Console (Monetize › In-app products). Both are
/// one-time purchases. Gold uses the same Product ID as a Durable add-on in
/// Microsoft Partner Center; Clear is not sold on Windows (no ads there).
const clearId = 'pagelume_clear'; // removes ads
const goldId = 'pagelume_gold'; // every Gold tool, and no ads

/// Tools that need Pagelume Gold. Each can be tried [freeTries] times first.
enum GoldFeature { sign, text, shapes, deletePages, translateDoc, ocr, flipStyle, ambient }

const freeTries = 3;

/// Page-turn looks (FlipStyle indexes) free to everyone: curl, slide, fade.
const freeFlipStyles = {0, 2, 3};

/// Background sounds (indexes) free to everyone: the first three.
const freeAmbient = {0, 1, 2};

/// What the person has bought. The Android app sells Gold and Clear through
/// Google Play, the iOS app through the App Store; the Windows app installed
/// from the Microsoft Store sells Gold. Elsewhere (the Windows zip)
/// everything is open.
class Purchases extends ChangeNotifier {
  Purchases._(this._prefs, {required this.selling, this.microsoftStore = false});

  /// Until [load] runs (and in tests) nothing is sold and everything is open.
  static Purchases instance = Purchases.free();

  /// Nothing sold, everything open.
  Purchases.free() : this._(null, selling: false);

  /// Sets up [instance]. [selling] defaults to Android and iOS, or Windows
  /// when the app came as a Store package.
  static Future<Purchases> load({bool? selling}) async {
    final prefs = await SharedPreferences.getInstance();
    final windowsStore = selling == null && Platform.isWindows && await WindowsStore.isPackaged();
    if (windowsStore) giftEarlyUsers(prefs);
    final p = Purchases._(
      prefs,
      selling: selling ?? (Platform.isAndroid || Platform.isIOS || windowsStore),
      microsoftStore: windowsStore,
    );
    instance = p;
    return p;
  }

  /// Every tool was free on Windows until Gold went on sale there. People who
  /// had already used the app (it saved some setting or recent book) keep
  /// everything as a gift; new installs get the free tries and the offer.
  /// Runs once, before anything else is saved on this start.
  @visibleForTesting
  static void giftEarlyUsers(SharedPreferences prefs) {
    if (prefs.containsKey('goldEra')) return;
    prefs.setBool('goldGift', prefs.getKeys().isNotEmpty);
    prefs.setBool('goldEra', true);
  }

  final SharedPreferences? _prefs;
  final bool selling;

  /// Prices as Google Play shows them, once loaded.
  final products = <String, ProductDetails>{};
  bool storeReady = false;

  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Cached on the device so it works offline; checked with the store on
  /// every start.
  bool get hasGold =>
      !selling || (_prefs?.getBool('owns_$goldId') ?? false) || (_prefs?.getBool('goldGift') ?? false);

  /// Selling through the Microsoft Store (the Windows app from the Store)
  /// rather than Google Play.
  final bool microsoftStore;
  bool get _windows => selling && microsoftStore;

  /// Selling through the App Store (iOS).
  bool get appStore => selling && !microsoftStore && Platform.isIOS;

  /// Set while the App Store is sending back earlier purchases.
  Completer<void>? _restoring;

  /// Store ids of the Windows add-ons, by Product ID.
  final _storeIds = <String, String>{};
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
    if (_windows) return _startWindows();
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
      // The App Store may ask for the Apple Account password to restore, so
      // that waits for the Restore button; what was bought is kept on the
      // device, and unfinished purchases arrive on the stream by themselves.
      if (!appStore) await _checkOwned();
    } catch (e) {
      debugPrint('store unavailable: $e');
    }
  }

  /// Loads the Gold price from the Microsoft Store and checks what this
  /// Microsoft account owns.
  Future<void> _startWindows() async {
    try {
      final addOns = await WindowsStore.products();
      final gold = addOns[goldId];
      if (gold != null) {
        _storeIds[goldId] = gold.storeId;
        products[goldId] = ProductDetails(
          id: goldId,
          title: gold.title,
          description: '',
          price: gold.price,
          rawPrice: 0,
          currencyCode: '',
        );
      }
      storeReady = true;
      notifyListeners();
      await _checkOwned();
    } catch (e) {
      debugPrint('Microsoft Store unavailable: $e');
    }
  }

  /// Asks the store for everything this account owns.
  Future<bool> _checkOwned() async {
    if (appStore) return _restoreApple();
    if (_windows) {
      final owned = await WindowsStore.owned();
      _own(goldId, owned.contains(goldId));
      return true;
    }
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

  /// Asks the App Store to send back earlier purchases, and waits a little
  /// for them (nothing comes back when nothing was bought).
  Future<bool> _restoreApple() async {
    final done = _restoring = Completer<void>();
    try {
      await InAppPurchase.instance.restorePurchases();
      await done.future.timeout(const Duration(seconds: 5), onTimeout: () {});
      return true;
    } finally {
      _restoring = null;
    }
  }

  /// Shown in a snack bar by [showPaywall]'s caller.
  final messages = StreamController<String Function(S)>.broadcast();

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _own(p.productID, true);
          // A restore says what it found itself, once, when it is done.
          if (_restoring == null) messages.add((s) => p.productID == goldId ? s.thanksGold : s.thanksClear);
        case PurchaseStatus.pending:
          messages.add((s) => s.purchasePending);
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          break;
      }
      // Google refunds purchases that are not acknowledged within 3 days.
      if (p.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(p);
    }
    final r = _restoring;
    if (r != null && !r.isCompleted && list.isNotEmpty) r.complete();
  }

  Future<void> buy(String id) async {
    final p = products[id];
    if (p == null) return;
    if (_windows) return _buyWindows(id);
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
  }

  Future<void> _buyWindows(String id) async {
    final storeId = _storeIds[id];
    if (storeId == null) return;
    try {
      switch (await WindowsStore.buy(storeId)) {
        case StoreBuyResult.succeeded:
        case StoreBuyResult.alreadyPurchased:
          _own(id, true);
          messages.add((s) => s.thanksGold);
        case StoreBuyResult.notPurchased:
          break; // closed the Store window
        case StoreBuyResult.networkError:
        case StoreBuyResult.serverError:
          messages.add((s) => s.msStoreUnavailable);
      }
    } catch (e) {
      debugPrint('Microsoft Store purchase failed: $e');
      messages.add((s) => s.msStoreUnavailable);
    }
  }

  /// Re-checks with the store. Returns false when it cannot be reached.
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

/// Lets the offer open from a snack bar that outlives the screen it came from.
final appNavigator = GlobalKey<NavigatorState>();

/// The Gold and Clear offer, with restore.
Future<void> showPaywall(BuildContext context, {bool locked = false}) async {
  if (!context.mounted) {
    final nav = appNavigator.currentContext;
    if (nav == null || !nav.mounted) return;
    context = nav;
  }
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
                  Text(p.microsoftStore ? s.goldPitchWin : s.goldPitch, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(s.goldFeatures, textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  if (!p.storeReady || gold == null)
                    Text(_unavailable(p, s), textAlign: TextAlign.center)
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
                          ? _unavailable(p, s)
                          : p.hasGold
                          ? s.thanksGold
                          : p.hasClear
                          ? s.thanksClear
                          : p.microsoftStore
                          ? s.msRestoredNone
                          : p.appStore
                          ? s.appleRestoredNone
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

/// "The store can't be reached", naming the store this app sells through.
String _unavailable(Purchases p, S s) =>
    p.microsoftStore ? s.msStoreUnavailable : (p.appStore ? s.appStoreUnavailable : s.storeUnavailable);
