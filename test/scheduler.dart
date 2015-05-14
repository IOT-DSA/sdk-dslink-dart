import "dart:async";

import "package:dslink/utils.dart";

main() {
  Scheduler.after(new Duration(seconds: 5), () {
    print("It's 5 seconds later.");
  });
}
