#pragma once
#include "ButtonGate.h"

// Portable session policy shared by the sketch and its regression tests.
class ButtonSession {
 public:
  enum class Output { None, Press, StateUp, StateDown };
  static constexpr uint32_t heartbeatMs = 1000;

  void disconnect(bool pressed, uint32_t now) {
    mode_ = Mode::Idle;
    button_.reset(pressed, now);
  }

  void hello(bool pressed, uint32_t now) {
    mode_ = Mode::Production;
    button_.reset(pressed, now);
  }

  Output test(bool pressed, uint32_t now) {
    mode_ = Mode::Diagnostics;
    button_.reset(pressed, now);
    reportedAt_ = now;
    // The immediate snapshot samples the current pin; subsequent transitions
    // require the same 25 ms debounce as production presses.
    return state();
  }

  Output update(bool pressed, uint32_t now) {
    if (mode_ == Mode::Idle) return Output::None;
    const bool previous = button_.stablePressed();
    const bool fired = button_.update(pressed, now);
    if (mode_ == Mode::Production) return fired ? Output::Press : Output::None;
    if (previous != button_.stablePressed() ||
        uint32_t(now - reportedAt_) >= heartbeatMs) {
      reportedAt_ = now;
      return state();
    }
    return Output::None;
  }

 private:
  enum class Mode { Idle, Production, Diagnostics };
  Output state() const {
    return button_.stablePressed() ? Output::StateDown : Output::StateUp;
  }
  ButtonGate button_;
  Mode mode_ = Mode::Idle;
  uint32_t reportedAt_ = 0;
};
