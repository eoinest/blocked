#include "../blocked_key/ButtonGate.h"
#include <cassert>
#include <iostream>

int main() {
  ButtonGate button;
  button.reset(true, 0); // Plugged in with the key already held.
  assert(!button.update(true, 10000));
  assert(!button.update(false, 10001));
  assert(!button.update(false, 10026));
  assert(!button.update(true, 10027));
  assert(button.update(true, 10052));
  assert(!button.update(true, 90000)); // No key repeat.

  button.reset(false, 0);
  assert(!button.update(false, 25));
  assert(!button.update(true, 30));
  assert(!button.update(false, 35)); // Contact bounce.
  assert(!button.update(true, 40));
  assert(!button.update(true, 64));
  assert(button.update(true, 65));
  assert(!button.update(false, 70));
  assert(!button.update(true, 72));
  assert(!button.update(true, 100)); // Release bounce cannot re-arm.
  assert(!button.update(false, 101));
  assert(!button.update(false, 126));
  assert(!button.update(true, 127));
  assert(button.update(true, 152));

  button.reset(true, 153); // HELLO / reconnect while held.
  assert(!button.update(true, 1000));
  assert(!button.update(false, 1001));
  assert(!button.update(true, 1002)); // A sub-25ms release is insufficient.
  assert(!button.update(true, 1100));

  button.reset(false, UINT32_MAX - 10);
  assert(!button.update(false, 15)); // Clock wrapped, release is now stable.
  assert(!button.update(true, 16));
  assert(button.update(true, 41));
  std::cout << "Button gate: boot, hold, bounce, reconnect, and clock-wrap checks passed\n";
}
