import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_flip_reader/l10n.dart';
import 'package:pdf_flip_reader/purchases.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Purchases.instance = Purchases.free());

  test('nothing is locked where nothing is sold', () async {
    final p = await Purchases.load(selling: false);
    expect(p.hasGold, isTrue);
    expect(p.adsOff, isFalse);
    expect(p.flipStyleOk(7), isTrue);
    expect(p.ambientOk(9), isTrue);
  });

  test('Clear removes ads only; Gold opens everything', () async {
    final p = await Purchases.load(selling: true);
    expect(p.hasGold, isFalse);
    expect(p.adsOff, isFalse);
    expect([for (var i = 0; i < 8; i++) p.flipStyleOk(i)], [true, false, true, true, false, false, false, false]);
    expect(p.ambientOk(-1), isTrue);
    expect(p.ambientOk(2), isTrue);
    expect(p.ambientOk(3), isFalse);

    p.grant(clearId);
    expect(p.adsOff, isTrue);
    expect(p.hasGold, isFalse);

    p.grant(clearId, false);
    p.grant(goldId);
    expect(p.adsOff, isTrue);
    expect(p.hasGold, isTrue);
    expect(p.flipStyleOk(7), isTrue);
    expect(p.ambientOk(9), isTrue);
  });

  testWidgets('three free tries, then the Gold offer', (tester) async {
    final p = await Purchases.load(selling: true);
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    for (var left = 2; left >= 0; left--) {
      expect(await requireGold(ctx, GoldFeature.sign), isTrue);
      await tester.pump();
      expect(find.text(S('en').goldTryLeft(left)), findsOneWidget);
      expect(p.triesLeft(GoldFeature.sign), left);
    }
    // Other tools keep their own tries.
    expect(p.triesLeft(GoldFeature.ocr), freeTries);

    bool? allowed;
    requireGold(ctx, GoldFeature.sign).then((v) => allowed = v);
    await tester.pumpAndSettle();
    expect(find.text('Pagelume Gold'), findsOneWidget);
    expect(find.text(S('en').goldLocked), findsOneWidget);
    // No Google Play in tests: the offer says so instead of showing prices.
    expect(find.text(S('en').storeUnavailable), findsOneWidget);
    Navigator.of(tester.element(find.text('Pagelume Gold'))).pop();
    await tester.pumpAndSettle();
    await tester.pump();
    expect(find.text('Pagelume Gold'), findsNothing);
    for (var i = 0; i < 5 && allowed == null; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(allowed, isFalse);
  });

  test('every language has the Gold texts', () {
    for (final code in S.codes) {
      final s = S(code);
      expect(s.goldTryLeft(2), contains('2'), reason: code);
      expect(s.buyGold('฿199'), contains('฿199'), reason: code);
      expect(s.buyClear('฿99'), contains('Pagelume Clear'), reason: code);
    }
  });
}
