import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob ids. These are Google's public TEST ids: they show sample ads and
/// earn nothing. Replace them with your own from admob.google.com before
/// publishing (and the App IDs in AndroidManifest.xml / Info.plist).
class AdIds {
  static String get banner =>
      Platform.isIOS ? 'ca-app-pub-3940256099942544/2934735716' : 'ca-app-pub-3940256099942544/6300978111';
}

bool _adsReady = false;

/// Starts the ads SDK. Ads are limited to G (general audiences) content; further
/// category blocking is set in the AdMob website (Blocking controls).
Future<void> initAds() async {
  if (!(Platform.isAndroid || Platform.isIOS)) return;
  try {
    await MobileAds.instance.updateRequestConfiguration(RequestConfiguration(maxAdContentRating: MaxAdContentRating.g));
    await MobileAds.instance.initialize();
    _adsReady = true;
  } catch (e) {
    debugPrint('ads unavailable: $e');
  }
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
    if (!_adsReady) return;
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
