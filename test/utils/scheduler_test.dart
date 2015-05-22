library dslink.test.common.scheduler;

import "dart:async";

import "package:test/test.dart";
import "package:dslink/utils.dart" show Scheduler, Interval;

void main() {
  group("Scheduler", schedulerTests);
}

void schedulerTests() {
  test("runs after a 2 millisecond delay", () {
    var completer = new Completer.sync();

    Scheduler.after(new Duration(milliseconds: 2), () {
      completer.complete();
    });

    return new Future.delayed(new Duration(milliseconds: 5), () {
      expect(completer.isCompleted, isTrue, reason: "Completer should be completed.");
    });
  });

  test("schedules a function on the event loop", () {
    var completer = new Completer.sync();

    Scheduler.runLater(() {
      completer.complete();
    });

    return new Future(() {
      expect(completer.isCompleted, isTrue, reason: "Completer should be completed.");
    });
  });

  test("schedules a function later", () {
    var completer = new Completer.sync();

    Scheduler.later(() {
      completer.complete();
    });

    return new Future(() {
      expect(completer.isCompleted, isTrue, reason: "Completer should be completed.");
    });
  });
}
