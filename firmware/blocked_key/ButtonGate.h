#pragma once
#include <stdint.h>

// Release-before-arm prevents a held key from firing on boot or reconnect.
// now is an unsigned millisecond clock; subtraction also works across wrap.
class ButtonGate {
 public:
  static constexpr uint32_t debounceMs = 25;

  void reset(bool pressed, uint32_t now) {
    raw_ = pressed;
    stable_ = pressed;
    changedAt_ = now;
    armed_ = false;
  }

  bool update(bool pressed, uint32_t now) {
    if (pressed != raw_) {
      raw_ = pressed;
      changedAt_ = now;
    }
    if (uint32_t(now - changedAt_) < debounceMs) return false;
    if (!raw_) {
      stable_ = false;
      armed_ = true;
      return false;
    }
    if (!stable_) {
      stable_ = true;
      const bool fire = armed_;
      armed_ = false;
      return fire;
    }
    return false;
  }

 private:
  bool raw_ = false;
  bool stable_ = false;
  bool armed_ = false;
  uint32_t changedAt_ = 0;
};
