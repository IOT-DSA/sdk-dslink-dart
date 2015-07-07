library dslink.test.utils.logger;

import "package:test/test.dart";
import "package:logging/logging.dart";

import "package:dslink/utils.dart";

main() => group("Logger", loggingTests);

loggingTests() {
  test("level update works as expected", () {
    expect(logger.level, equals(Level.INFO));
    updateLogLevel("FINE");
    expect(logger.level, equals(Level.FINE));
  });
}
