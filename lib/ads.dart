import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob ids. The Play Store build (`--dart-define=REAL_ADS=true`) shows real
/// ads from the Pagelume banner unit. The APKs for installing by hand use
/// Google's public test unit, so the owner's own phone never shows (or
/// clicks) real ads, which AdMob forbids.
class AdIds {
  static const real = bool.fromEnvironment('REAL_ADS');

  static String get banner => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/2934735716'
      : real
      ? 'ca-app-pub-5301402884438261/2788460148'
      : 'ca-app-pub-3940256099942544/6300978111';
}

/// True once ads may be requested (consent gathered and SDK started).
final adsReady = ValueNotifier(false);

/// Starts the ads SDK. Ads are limited to G (general audiences) content; further
/// category blocking is set in the AdMob website (Blocking controls).
///
/// First asks for consent where the law requires it (EEA, UK, some US
/// states), using the consent message set up in AdMob > Privacy & messaging.
/// Runs after the app is on screen so it never delays opening a book.
Future<void> initAds() async {
  if (!(Platform.isAndroid || Platform.isIOS)) return;
  try {
    await _gatherConsent();
    if (!await ConsentInformation.instance.canRequestAds()) return;
    await MobileAds.instance.updateRequestConfiguration(RequestConfiguration(maxAdContentRating: MaxAdContentRating.g));
    await MobileAds.instance.initialize();
    adsReady.value = true;
  } catch (e) {
    debugPrint('ads unavailable: $e');
  }
}

Future<void> _gatherConsent() {
  final done = Completer<void>();
  void finish([Object? _]) {
    if (!done.isCompleted) done.complete();
  }

  ConsentInformation.instance.requestConsentInfoUpdate(
    ConsentRequestParameters(),
    () => ConsentForm.loadAndShowConsentFormIfRequired(finish),
    finish,
  );
  return done.future;
}

/// A small banner. Shown only on the file screen, never while reading, so
/// nothing appears on the projector.
class BannerSlot extends StatefulWidget {
  const BannerSlot({super.key});

  @override
  State<BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<BannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    adsReady.addListener(_load);
    _load();
  }

  void _load() {
    if (!adsReady.value || _ad != null || !mounted) return;
    _ad = BannerAd(
      adUnitId: AdIds.banner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _loaded = true),
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  @override
  void dispose() {
    adsReady.removeListener(_load);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
