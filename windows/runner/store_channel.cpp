#include "store_channel.h"

#include <appmodel.h>
#include <flutter/standard_method_codec.h>
#include <shobjidl.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Services.Store.h>

#include <string>
#include <utility>

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;
using winrt::Windows::Foundation::AsyncStatus;
using winrt::Windows::Foundation::IAsyncOperation;
using winrt::Windows::Services::Store::StoreAppLicense;
using winrt::Windows::Services::Store::StoreContext;
using winrt::Windows::Services::Store::StoreProductQueryResult;
using winrt::Windows::Services::Store::StorePurchaseResult;
using Result = std::shared_ptr<flutter::MethodResult<EncodableValue>>;

std::string Utf8(const winrt::hstring& s) { return winrt::to_string(s); }

// A StoreContext that shows its windows (sign-in, purchase) over ours.
StoreContext ContextFor(HWND window) {
  StoreContext context = StoreContext::GetDefault();
  context.as<IInitializeWithWindow>()->Initialize(window);
  return context;
}

// When |op| finishes, turns its result into a reply with |convert| and queues
// it for the window thread.
template <typename T, typename Convert>
void ReplyWhenDone(IAsyncOperation<T> op, Result result, HWND window,
                   std::shared_ptr<StoreChannel::Queue> queue, Convert convert) {
  op.Completed([result, window, queue, convert](const IAsyncOperation<T>& done, AsyncStatus) {
    std::function<void()> reply;
    try {
      EncodableValue value = convert(done.GetResults());
      reply = [result, value] { result->Success(value); };
    } catch (const winrt::hresult_error& e) {
      std::string message = Utf8(e.message());
      int32_t code = static_cast<int32_t>(e.code());
      reply = [result, message, code] {
        result->Error("store_error", message, EncodableValue(code));
      };
    } catch (...) {
      reply = [result] { result->Error("store_error", "unknown error"); };
    }
    {
      std::lock_guard<std::mutex> lock(queue->mutex);
      queue->replies.push_back(std::move(reply));
    }
    PostMessage(window, StoreChannel::kDoneMessage, 0, 0);
  });
}

// Durable add-ons for sale: [{token, storeId, title, price}].
EncodableValue ProductList(const StoreProductQueryResult& r) {
  winrt::check_hresult(r.ExtendedError());
  EncodableList list;
  for (const auto& pair : r.Products()) {
    const auto& product = pair.Value();
    list.push_back(EncodableValue(EncodableMap{
        {EncodableValue("token"), EncodableValue(Utf8(product.InAppOfferToken()))},
        {EncodableValue("storeId"), EncodableValue(Utf8(product.StoreId()))},
        {EncodableValue("title"), EncodableValue(Utf8(product.Title()))},
        {EncodableValue("price"), EncodableValue(Utf8(product.Price().FormattedPrice()))},
    }));
  }
  return EncodableValue(list);
}

// Product IDs (in-app offer tokens) of the add-ons this account owns.
EncodableValue OwnedList(const StoreAppLicense& license) {
  EncodableList list;
  for (const auto& pair : license.AddOnLicenses()) {
    if (pair.Value().IsActive()) {
      list.push_back(EncodableValue(Utf8(pair.Value().InAppOfferToken())));
    }
  }
  return EncodableValue(list);
}

bool IsPackaged() {
  UINT32 length = 0;
  return GetCurrentPackageFullName(&length, nullptr) != APPMODEL_ERROR_NO_PACKAGE;
}

}  // namespace

StoreChannel::StoreChannel(flutter::BinaryMessenger* messenger, HWND window)
    : window_(window) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "pagelume/store", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    Handle(call, std::move(result));
  });
}

void StoreChannel::Handle(const flutter::MethodCall<EncodableValue>& call,
                          std::unique_ptr<flutter::MethodResult<EncodableValue>> unique) {
  Result result(std::move(unique));
  const std::string& method = call.method_name();
  try {
    if (method == "isPackaged") {
      result->Success(EncodableValue(IsPackaged()));
    } else if (method == "products") {
      ReplyWhenDone(ContextFor(window_).GetAssociatedStoreProductsAsync({L"Durable"}), result,
                    window_, queue_, ProductList);
    } else if (method == "owned") {
      ReplyWhenDone(ContextFor(window_).GetAppLicenseAsync(), result, window_, queue_, OwnedList);
    } else if (method == "buy") {
      std::string store_id;
      if (const auto* args = std::get_if<EncodableMap>(call.arguments())) {
        auto it = args->find(EncodableValue("storeId"));
        if (it != args->end()) {
          if (const auto* s = std::get_if<std::string>(&it->second)) store_id = *s;
        }
      }
      if (store_id.empty()) {
        result->Error("bad_args", "storeId is missing");
        return;
      }
      // Returns StorePurchaseStatus as an int (0 succeeded, 1 already owned,
      // 2 not purchased, 3 network error, 4 server error).
      ReplyWhenDone(ContextFor(window_).RequestPurchaseAsync(winrt::to_hstring(store_id)), result,
                    window_, queue_, [](const StorePurchaseResult& r) {
                      return EncodableValue(static_cast<int32_t>(r.Status()));
                    });
    } else {
      result->NotImplemented();
    }
  } catch (const winrt::hresult_error& e) {
    result->Error("store_error", Utf8(e.message()), EncodableValue(static_cast<int32_t>(e.code())));
  }
}

void StoreChannel::RunFinished() {
  std::deque<std::function<void()>> ready;
  {
    std::lock_guard<std::mutex> lock(queue_->mutex);
    ready.swap(queue_->replies);
  }
  for (auto& reply : ready) reply();
}
