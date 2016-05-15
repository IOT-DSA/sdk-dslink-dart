library dslink.historian;

import "dart:async";
import "dart:math";

import "package:dslink/dslink.dart";
import "package:dslink/nodes.dart";
import "package:dslink/utils.dart";

part "src/historian/interval.dart";
part "src/historian/rollup.dart";
part "src/historian/get_history.dart";
part "src/historian/manage.dart";
part "src/historian/values.dart";
part "src/historian/adapter.dart";
part "src/historian/container.dart";
part "src/historian/publish.dart";
part "src/historian/main.dart";

LinkProvider _link;
HistorianAdapter _historian;

HistorianAdapter get historian => _historian;
LinkProvider get link => _link;
