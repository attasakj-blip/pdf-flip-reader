import 'package:flutter/services.dart';

/// An add-on as the Microsoft Store sells it.
class StoreAddOn {
  const StoreAddOn({required this.storeId, required this.title, required this.price});

  /// The Store's own id for the add-on (needed to buy it).
  final String storeId;
  final String title;

  /// Already formatted in the buyer's currency, such as "฿199.00".
  final String price;
}

/// Result of [WindowsStore.buy], in the order of Windows' StorePurchaseStatus.
enum StoreBuyResult { succeeded, alreadyPurchased, notPurchased, networkError, serverError }

/// Talks to the Microsoft Store through windows/runner/store_channel.cpp.
///
/// Add-ons are named by their Product ID in Partner Center (the Store calls
/// it the in-app offer token), so Gold is 'pagelume_gold' as on Android.
class WindowsStore {
  static const _channel = MethodChannel('pagelume/store');

  /// True when the app runs from an MSIX package (the Store or the test
  /// package), false for the zip, which cannot buy anything.
  static Future<bool> isPackaged() async {
    try {
      return await _channel.invokeMethod<bool>('isPackaged') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Durable add-ons for sale, by Product ID.
  static Future<Map<String, StoreAddOn>> products() async {
    final list = await _channel.invokeListMethod<Map<Object?, Object?>>('products') ?? const [];
    return {
      for (final m in list)
        '${m['token']}': StoreAddOn(storeId: '${m['storeId']}', title: '${m['title']}', price: '${m['price']}'),
    };
  }

  /// Product IDs of the add-ons this Microsoft account owns.
  static Future<Set<String>> owned() async =>
      {...?await _channel.invokeListMethod<String>('owned')};

  /// Shows the Store's purchase window for [storeId].
  static Future<StoreBuyResult> buy(String storeId) async {
    final i = await _channel.invokeMethod<int>('buy', {'storeId': storeId}) ?? StoreBuyResult.serverError.index;
    return StoreBuyResult.values[i.clamp(0, StoreBuyResult.values.length - 1)];
  }
}
