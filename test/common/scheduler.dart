library dslink.test.common.scheduler;

import "dart:async";

import "package:test/test.dart";
import "package:dslink/utils.dart" show Scheduler, Interval;

void main() {
  group("Scheduler", schedulerTests);
}

void schedulerTests() {
  test("runs after a 2 second delay", () {
    var completer = new Completer();

    Scheduler.after(new Duration(seconds: 1), () {
      completer.complete();
    });

    return new Future.delayed(new Duration(milliseconds: 1500), () {
      expect(completer.isCompleted, isTrue, reason: "Completer should be completed.");
    });
  });
}
