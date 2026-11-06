#ifndef RUNNER_STORE_CHANNEL_H_
#define RUNNER_STORE_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <deque>
#include <functional>
#include <memory>
#include <mutex>

// The "pagelume/store" method channel: Pagelume Gold through the Microsoft
// Store (Windows.Services.Store). Store calls are started on the window
// thread (the purchase window needs it) and finish on a background thread;
// their answers are queued and handed back to the window thread with
// kDoneMessage, because Flutter replies must be sent from that thread.
class StoreChannel {
 public:
  static constexpr UINT kDoneMessage = WM_APP + 0x51;

  StoreChannel(flutter::BinaryMessenger* messenger, HWND window);

  // Call from the window procedure on kDoneMessage.
  void RunFinished();

  // Replies waiting for the window thread. Shared with Store callbacks so it
  // outlives this object if the app closes mid-call.
  struct Queue {
    std::mutex mutex;
    std::deque<std::function<void()>> replies;
  };

 private:
  void Handle(const flutter::MethodCall<flutter::EncodableValue>& call,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND window_;
  std::shared_ptr<Queue> queue_ = std::make_shared<Queue>();
};

#endif  // RUNNER_STORE_CHANNEL_H_
