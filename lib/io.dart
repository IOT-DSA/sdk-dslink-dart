/// DSLink SDK IO Utilities
library dslink.io;

import "dart:async";
import "dart:convert";
import "dart:io";

Stream<String> readStdinText() => stdin.transform(UTF8.decoder);
Stream<String> readStdinLines() =>
    readStdinText().transform(new LineSplitter());
