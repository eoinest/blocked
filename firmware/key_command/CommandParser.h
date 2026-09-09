#pragma once
#include <stddef.h>
#include <string.h>

// Exact, bounded ASCII commands. Malformed lines are discarded through LF.
class CommandParser {
 public:
  enum class Command { None, Hello, Test };
  static constexpr size_t capacity = 63;

  void reset() { length_ = 0; invalid_ = false; trailingCR_ = false; }

  Command feed(char byte) {
    if (byte == '\n') {
      Command result = Command::None;
      if (!invalid_) {
        if (matches("KEY_COMMAND_HELLO")) result = Command::Hello;
        else if (matches("KEY_COMMAND_TEST")) result = Command::Test;
      }
      reset();
      return result;
    }
    if (invalid_) return Command::None;
    if (trailingCR_) invalid_ = true;
    else if (byte == '\r') trailingCR_ = true;
    else if (byte < 0x20 || byte > 0x7e || length_ == capacity) invalid_ = true;
    else bytes_[length_++] = byte;
    return Command::None;
  }

 private:
  bool matches(const char *value) const {
    return length_ == strlen(value) && memcmp(bytes_, value, length_) == 0;
  }
  char bytes_[capacity];
  size_t length_ = 0;
  bool invalid_ = false;
  bool trailingCR_ = false;
};
