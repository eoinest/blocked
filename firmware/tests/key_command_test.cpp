#include "../key_command/ButtonGate.h"
#include "../key_command/ButtonSession.h"
#include "../key_command/CommandParser.h"
#include <cassert>
#include <string>
#include <iostream>

using Command = CommandParser::Command;
Command line(CommandParser &parser, const std::string &bytes) {
  Command result = Command::None;
  for (const char byte : bytes) {
    const auto next = parser.feed(byte);
    if (next != Command::None) {
      assert(result == Command::None);
      result = next;
    }
  }
  return result;
}

int main() {
  CommandParser parser;
  assert(line(parser, "KEY_COMMAND_HELLO\n") == Command::Hello);
  assert(line(parser, "KEY_COMMAND_TEST\r\n") == Command::Test);
  for (const auto invalid : {"HELLO\n", "TEST\n", "KEY_COMMAND_HELLO extra\n",
       " KEY_COMMAND_HELLO\n", "key_command_hello\n", "KEY_COMMAND_\rHELLO\n",
       "KEY_COMMAND_HELLO\r\r\n", "\n"}) {
    assert(line(parser, invalid) == Command::None);
  }
  assert(line(parser, std::string("KEY_COMMAND_HELLO\0\n", 19)) == Command::None);
  assert(line(parser, std::string(64, 'x') + "KEY_COMMAND_HELLO\n") == Command::None);
  assert(line(parser, "KEY_COMMAND_HELLO\n") == Command::Hello); // Recovers at LF.
  assert(line(parser, "KEY_COMMAND_") == Command::None);
  parser.reset(); // Partial command cannot bridge a disconnect.
  assert(line(parser, "HELLO\n") == Command::None);

  // Exercise actual parser decisions driving the session, including cross-product
  // isolation and offline activity that must never replay after a handshake.
  ButtonSession protocolSession;
  auto command = [&](const std::string &bytes, bool pressed, uint32_t now) {
    const auto result = line(parser, bytes);
    if (result == Command::Hello) protocolSession.hello(pressed, now);
    if (result == Command::Test) protocolSession.test(pressed, now);
  };
  command("HELLO\n", false, 0);
  assert(protocolSession.update(false, 25) == ButtonSession::Output::None);
  assert(protocolSession.update(true, 30) == ButtonSession::Output::None);
  assert(protocolSession.update(true, 55) == ButtonSession::Output::None);
  command("KEY_COMMAND_HELLO\n", true, 60);
  assert(protocolSession.update(true, 100) == ButtonSession::Output::None);
  assert(protocolSession.update(false, 101) == ButtonSession::Output::None);
  assert(protocolSession.update(false, 126) == ButtonSession::Output::None);
  assert(protocolSession.update(true, 127) == ButtonSession::Output::None);
  assert(protocolSession.update(true, 152) == ButtonSession::Output::Press);
  command("KEY_COMMAND_TEST\n", true, 153);
  assert(protocolSession.update(false, 154) == ButtonSession::Output::None);
  assert(protocolSession.update(false, 179) == ButtonSession::Output::StateUp);
  assert(protocolSession.update(true, 180) == ButtonSession::Output::None);
  assert(protocolSession.update(true, 205) == ButtonSession::Output::StateDown);
  protocolSession.disconnect(true, 206);
  assert(protocolSession.update(true, 5000) == ButtonSession::Output::None);
  std::cout << "Key Command: exact parser, overflow, binary/CR rejection, isolation, and mode checks passed\n";

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

  using Output = ButtonSession::Output;
  ButtonSession session;
  assert(session.update(true, 0) == Output::None); // Idle never emits.
  assert(session.test(true, 100) == Output::StateDown); // Held-start snapshot.
  assert(session.update(true, 1099) == Output::None);
  assert(session.update(true, 1100) == Output::StateDown); // Held heartbeat.
  assert(session.update(false, 1110) == Output::None);
  assert(session.update(true, 1120) == Output::None); // Release bounce.
  assert(session.update(false, 1130) == Output::None);
  assert(session.update(false, 1154) == Output::None);
  assert(session.update(false, 1155) == Output::StateUp);
  assert(session.update(true, 1160) == Output::None);
  assert(session.update(false, 1170) == Output::None); // Press bounce.
  assert(session.update(true, 1180) == Output::None);
  assert(session.update(true, 1204) == Output::None);
  assert(session.update(true, 1205) == Output::StateDown); // Never PRESS in TEST.
  assert(session.update(true, 2204) == Output::None);
  assert(session.update(true, 2205) == Output::StateDown);

  session.hello(true, 2300); // Leaving TEST while held cannot fire.
  assert(session.update(true, 4000) == Output::None); // Nor heartbeat in HELLO.
  assert(session.update(false, 4001) == Output::None);
  assert(session.update(false, 4026) == Output::None);
  assert(session.update(true, 4027) == Output::None);
  assert(session.update(true, 4052) == Output::Press);
  assert(session.update(true, 6000) == Output::None);
  assert(session.test(false, 6001) == Output::StateUp); // TEST replaces HELLO.
  session.disconnect(false, 6002);
  assert(session.update(true, 9000) == Output::None); // No diagnostics after disconnect.
  session.hello(false, 9001);
  assert(session.update(true, 9002) == Output::None); // No stable release since HELLO.
  assert(session.update(true, 9027) == Output::None);

  assert(session.test(false, UINT32_MAX - 499) == Output::StateUp);
  assert(session.update(false, 499) == Output::None);
  assert(session.update(false, 500) == Output::StateUp); // Heartbeat across wrap.
  assert(session.test(true, 501) == Output::StateDown); // Repeated TEST resnapshots.
  assert(session.update(true, 1500) == Output::None);
  assert(session.update(true, 1501) == Output::StateDown);
  std::cout << "Diagnostics: snapshots, debounce, heartbeat, mode changes, disconnect, and clock-wrap checks passed\n";
}
