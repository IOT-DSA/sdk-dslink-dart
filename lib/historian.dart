library dslink.historian;

import "dart:async";
import "dart:math";

import "package:dslink/dslink.dart";
import "package:dslink/nodes.dart";
import "package:dslink/utils.dart";

const Map<dynamic, int> INTERVAL_TYPES = const {
  const ["ms", "millis", "millisecond", "milliseconds"]: 1,
  const ["s", "second", "seconds"]: 1000,
  const ["m", "min", "minute", "minutes"]: 60000,
  const ["h", "hr", "hour", "hours"]: 3600000,
  const ["d", "day", "days"]: 86400000,
  const ["wk", "week", "weeks"]: 604800000,
  const ["n", "month", "months"]: 2628000000,
  const ["year", "years", "y"]: 31536000000
};

class HistorySummary {
  final ValuePair first;
  final ValuePair last;

  HistorySummary(this.first, this.last);
}

final List<String> INTERVAL_ALL_TYPES = INTERVAL_TYPES
  .keys
  .expand((key) => key)
  .toList()
  ..sort();

final RegExp INTERVAL_REGEX = new RegExp(
  "^(\\d*?.?\\d*?)(${INTERVAL_ALL_TYPES.join('|')})\$");

int parseInterval(String input) {
  if (input == null) {
    return 0;
  }

  /// Sanitize Input
  input = input.trim().toLowerCase().replaceAll(" ", "");

  if (input == "none") {
    return 0;
  }

  if (input == "default") {
    return 0;
  }

  if (!INTERVAL_REGEX.hasMatch(input)) {
    throw new FormatException("Bad Interval Syntax: ${input}");
  }

  var match = INTERVAL_REGEX.firstMatch(input);
  var multiplier = num.parse(match[1]);
  var typeName = match[2];
  var typeKey = INTERVAL_TYPES.keys.firstWhere((x) => x.contains(typeName));
  var type = INTERVAL_TYPES[typeKey];
  return (multiplier * type).round();
}

abstract class Rollup {
  dynamic get value;

  void add(dynamic input);

  void reset();
}

class FirstRollup extends Rollup {
  @override
  void add(input) {
    if (set) {
      return;
    }
    value = input;
    set = true;
  }

  @override
  void reset() {
    set = false;
  }

  dynamic value;
  bool set = false;
}

class LastRollup extends Rollup {
  @override
  void add(input) {
    value = input;
  }

  @override
  void reset() {
  }

  dynamic value;
}

class AvgRollup extends Rollup {
  @override
  void add(input) {
    if (input is String) {
      input = num.parse(input, (e) => input.length);
    }

    if (input is! num) {
      return;
    }

    total += input;
    count++;
  }

  @override
  void reset() {
    total = 0.0;
    count = 0;
  }

  dynamic total = 0.0;

  dynamic get value => total / count;
  int count = 0;
}

class SumRollup extends Rollup {
  @override
  void add(input) {
    if (input is String) {
      input = num.parse(input, (e) => input.length);
    }

    if (input is! num) {
      return;
    }

    value += input;
  }

  @override
  void reset() {
    value = 0.0;
  }

  dynamic value = 0.0;
}

class CountRollup extends Rollup {
  @override
  void add(input) {
    value++;
  }

  @override
  void reset() {
    value = 0;
  }

  dynamic value = 0;
}

class MaxRollup extends Rollup {
  @override
  void add(input) {
    if (input is String) {
      input = num.parse(input, (e) => null);
    }

    if (input is! num) {
      return;
    }

    value = max(value == null ? double.INFINITY : value, input);
  }

  @override
  void reset() {
    value = null;
  }

  dynamic value;
}

class MinRollup extends Rollup {
  @override
  void add(input) {
    if (input is String) {
      input = num.parse(input, (e) => null);
    }

    if (input is! num) {
      return;
    }

    value = min(value == null ? double.NEGATIVE_INFINITY : value, input);
  }

  @override
  void reset() {
    value = null;
  }

  dynamic value;
}

typedef Rollup RollupFactory();

final Map<String, RollupFactory> ROLLUPS = {
  "none": () => null,
  "delta": () => new FirstRollup(),
  "first": () => new FirstRollup(),
  "last": () => new LastRollup(),
  "max": () => new MaxRollup(),
  "min": () => new MinRollup(),
  "count": () => new CountRollup(),
  "sum": () => new SumRollup(),
  "avg": () => new AvgRollup()
};

class GetHistoryNode extends SimpleNode {
  GetHistoryNode(String path) : super(path, link.provider) {
    configs[r"$is"] = "getHistory";
    configs[r"$name"] = "Get History";
    configs[r"$invokable"] = "read";
    configs[r"$params"] = [
      {
        "name": "Timerange",
        "type": "string",
        "editor": "daterange"
      },
      {
        "name": "Interval",
        "type": "enum",
        "editor": buildEnumType([
          "default",
          "none",
          "1Y",
          "3N",
          "1N",
          "1W",
          "1D",
          "12H",
          "6H",
          "4H",
          "3H",
          "2H",
          "1H",
          "30M",
          "15M",
          "10M",
          "5M",
          "1M",
          "30S",
          "15S",
          "10S",
          "5S",
          "1S"
        ]),
        "default": "default"
      },
      {
        "name": "Rollup",
        "type": buildEnumType([
          "none",
          "avg",
          "min",
          "max",
          "sum",
          "first",
          "last",
          "count"
        ])
      },
      {
        "name": "Real Time",
        "type": "bool",
        "default": false
      }
    ];

    configs[r"$columns"] = [
      {
        "name": "timestamp",
        "type": "time"
      },
      {
        "name": "value",
        "type": "dynamic"
      }
    ];

    configs[r"$result"] = "stream";
  }

  @override
  onInvoke(Map<String, dynamic> params) async* {
    String range = params["Timerange"];
    String rollupName = params["Rollup"];
    RollupFactory rollupFactory = ROLLUPS[rollupName];
    Rollup rollup = rollupFactory == null ? null : rollupFactory();
    Duration interval = new Duration(
      milliseconds: parseInterval(params["Interval"]));

    TimeRange tr = parseTimeRange(range);
    if (params["Real Time"] == true) {
      tr = new TimeRange(tr.start, null);
    }

    try {
      Stream<ValuePair> pairs = await calculateHistory(tr, interval, rollup);

      if (params["Real Time"] == true) {
        await for (ValuePair pair in pairs) {
          yield [pair.toRow()];
        }
      } else {
        int count = 0;
        List<List<dynamic>> buffer = [];

        await for (ValuePair row in pairs) {
          count++;
          buffer.add(row.toRow());
          if (count == 10) {
            yield buffer;
            buffer = [];
            count = 0;
          }
        }

        if (buffer.isNotEmpty) {
          yield buffer;
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Stream<ValuePair> fetchHistoryData(TimeRange range) {
    var p = new Path(path);
    var mn = p.parent;
    WatchPathNode pn = link[mn.path];

    return pn.fetchHistory(range);
  }

  Stream<ValuePair> calculateHistory(TimeRange range,
    Duration interval,
    Rollup rollup) async* {
    if (interval.inMilliseconds <= 0) {
      yield* fetchHistoryData(range);
      return;
    }

    int lastTimestamp = -1;
    int totalTime = 0;

    ValuePair result;

    await for (ValuePair pair in fetchHistoryData(range)) {
      rollup.add(pair.value);
      if (lastTimestamp != -1) {
        totalTime += pair.time.millisecondsSinceEpoch - lastTimestamp;
      }
      lastTimestamp = pair.time.millisecondsSinceEpoch;
      if (totalTime >= interval.inMilliseconds) {
        totalTime = 0;
        result = new ValuePair(
          new DateTime.fromMillisecondsSinceEpoch(
            lastTimestamp
          ).toIso8601String(),
          rollup.value
        );
        yield result;
        result = null;
        rollup.reset();
      }
    }

    if (result != null) {
      yield result;
    }
  }
}

class ValuePair {
  final String timestamp;
  final dynamic value;

  DateTime get time => DateTime.parse(timestamp);

  ValuePair(this.timestamp, this.value);

  List toRow() {
    return [timestamp, value];
  }
}

LinkProvider link;

class CreateWatchGroupNode extends SimpleNode {
  CreateWatchGroupNode(String path) : super(path, link.provider);

  @override
  onInvoke(Map<String, dynamic> params) async {
    String name = params["Name"];
    String realName = NodeNamer.createName(name);

    var p = new Path(path);

    link.addNode("${p.parentPath}/${realName}", {
      r"$is": "watchGroup",
      r"$name": name
    });
    link.save();
  }
}

class AddDatabaseNode extends SimpleNode {
  AddDatabaseNode(String path) : super(path, link.provider);

  @override
  onInvoke(Map<String, dynamic> params) async {
    String name = params["Name"];
    String realName = NodeNamer.createName(name);

    link.addNode("/${realName}", {
      r"$is": "database",
      r"$name": name,
      r"$$db_config": params
    });
    link.save();
  }
}

class AddWatchPathNode extends SimpleNode {
  AddWatchPathNode(String path) : super(path);

  @override
  onInvoke(Map<String, dynamic> params) async {
    String wp = params["Path"];
    String rp = NodeNamer.createName(wp);
    var p = new Path(path);
    var targetPath = "${p.parentPath}/${rp}";
    var n = link.addNode(targetPath, {
      r"$name": wp,
      r"$value_path": wp,
      r"$is": "watchPath"
    });

    var node = await link.requester.getRemoteNode(wp);
    n.configs[r"$type"] = node.configs[r"$type"];
    n.listChangeController.add(r"$is");

    link.save();
  }
}

abstract class HistorianDatabaseAdapter {
  Future<HistorySummary> getSummary(String group, String path);

  Future store(List<ValueEntry> entries);

  Stream<ValuePair> fetchHistory(String group, String path, TimeRange range);

  Future purgePath(String group, String path, TimeRange range);

  Future purgeGroup(String group, TimeRange range);

  addWatchPathExtensions(WatchPathNode node) {}
  addWatchGroupExtensions(WatchGroupNode node) {}

  Future close();
}

class TimeRange {
  final DateTime start;
  final DateTime end;

  TimeRange(this.start, this.end);

  Duration get duration => end.difference(start);

  bool isWithin(DateTime time) {
    bool valid = (time.isAfter(start) || time.isAtSameMomentAs(start));
    if (end != null) {
      valid = valid && (time.isBefore(end) || time.isAtSameMomentAs(end));
    }
    return valid;
  }
}

class PurgePathNode extends SimpleNode {
  PurgePathNode(String path) : super(path);

  @override
  onInvoke(Map<String, dynamic> params) async {
    TimeRange tr = parseTimeRange(params["timeRange"]);
    if (tr == null) {
      return;
    }

    WatchPathNode watchPathNode = link[new Path(path).parentPath];
    await watchPathNode.group.db.database.purgePath(
      watchPathNode.group._watchName,
      watchPathNode.valuePath,
      tr
    );
  }
}

class PurgeGroupNode extends SimpleNode {
  PurgeGroupNode(String path) : super(path);

  @override
  onInvoke(Map<String, dynamic> params) async {
    TimeRange tr = parseTimeRange(params["timeRange"]);
    if (tr == null) {
      return;
    }

    WatchGroupNode watchGroupNode = link[new Path(path).parentPath];
    await watchGroupNode.db.database.purgeGroup(
      watchGroupNode._watchName,
      tr
    );
  }
}

abstract class HistorianAdapter {
  Future<HistorianDatabaseAdapter> getDatabase(Map config);

  List<Map<String, dynamic>> getCreateDatabaseParameters();
}

class WatchPathNode extends SimpleNode {
  String valuePath;
  WatchGroupNode group;

  WatchPathNode(String path) : super(path);

  @override
  onCreated() async {
    String rp = configs[r"$value_path"];
    valuePath = rp;
    group = link[new Path(path).parentPath];

    String groupName = group._watchName;

    link.addNode("${path}/lwv", {
      r"$name": "Last Written Value",
      r"$type": "dynamic"
    });

    link.addNode("${path}/startDate", {
      r"$name": "Start Date",
      r"$type": "string"
    });

    link.addNode("${path}/endDate", {
      r"$name": "End Date",
      r"$type": "string"
    });

    if (children["enabled"] == null) {
      link.addNode("${path}/enabled", {
        r"$name": "Enabled",
        r"$type": "bool",
        "?value": true,
        r"$writable": "write"
      });
    }

    if (group.db.database == null) {
      Completer c = new Completer();
      group.db.onDatabaseReady.add(c.complete);
      await c.future;
    }

    HistorySummary summary = await group.db.database.getSummary(groupName, valuePath);

    if (summary.first != null) {
      link.updateValue("${path}/startDate", summary.first.timestamp);
      isStartDateFilled = true;
    }

    if (summary.last != null) {
      ValueUpdate update = new ValueUpdate(summary.last.value, ts: summary.last.timestamp);
      link.updateValue("${path}/lwv", update);
      updateValue(update);
    }

    timer = Scheduler.safeEvery(const Duration(seconds: 1), () async {
      await storeBuffer();
    });

    var ghn = new GetHistoryNode("${path}/getHistory");
    addChild("getHistory", ghn);
    (link.provider as SimpleNodeProvider).setNode(ghn.path, ghn);
    updateList("getHistory");

    link.addNode("${path}/purge", {
      r"$name": "Purge",
      r"$invokable": "write",
      r"$params": [
        {
          "name": "timeRange",
          "type": "string",
          "editor": "daterange"
        }
      ],
      r"$is": "purgePath"
    });

    link.onValueChange("${path}/enabled").listen((ValueUpdate update) {
      if (update.value == true) {
        sub();
      } else {
        if (valueSub != null) {
          valueSub.cancel();
          valueSub = null;
        }
      }
    });

    if (link.val("${path}/enabled") == true) {
      sub();
    }

    group.db.database.addWatchPathExtensions(this);
  }

  ReqSubscribeListener valueSub;

  sub() {
    if (valueSub != null) {
      valueSub.cancel();
      valueSub = null;
    }

    valueSub = link.requester.subscribe(valuePath, (ValueUpdate update) {
      updateValue(update);
      buffer.add(update);
    });
  }

  ValueEntry asValueEntry(ValueUpdate update) {
    return new ValueEntry(group._watchName, valuePath, update.ts, update.value);
  }

  bool isStartDateFilled = false;

  storeBuffer() async {
    List<ValueEntry> entries = buffer.map(asValueEntry).toList();

    if (entries.isNotEmpty) {
      if (!isStartDateFilled) {
        link.updateValue("${path}/startDate", entries.first.timestamp);
      }

      link.updateValue("${path}/lwv", entries.last.value);
      link.updateValue("${path}/endDate", entries.last.timestamp);
    }
    buffer.clear();
    await group.storeValues(entries);
  }

  @override
  onRemoving() {
    if (timer != null) {
      timer.dispose();
    }

    storeBuffer();
  }

  @override
  Map save() {
    var out = super.save();
    out.remove("lwv");
    out.remove("startDate");
    out.remove("endDate");
    out.remove("getHistory");
    return out;
  }

  List<ValueUpdate> buffer = [];
  Disposable timer;

  Stream<ValuePair> fetchHistory(TimeRange range) {
    return group.fetchHistory(valuePath, range);
  }
}

class DatabaseNode extends SimpleNode {
  Map config;
  HistorianDatabaseAdapter database;
  List<Function> onDatabaseReady = [];

  DatabaseNode(String path) : super(path);

  @override
  onCreated() async {
    config = configs[r"$$db_config"];
    try {
      database = await historian.getDatabase(config);
      while (onDatabaseReady.isNotEmpty) {
        onDatabaseReady.removeAt(0)();
      }
    } catch (e, stack) {
      logger.severe("Failed to connect to database for ${path}", e, stack);
      remove();
    }

    link.addNode("${path}/createWatchGroup", {
      r"$name": "Add Watch Group",
      r"$is": "createWatchGroup",
      r"$invokable": "write",
      r"$params": [
        {
          "name": "Name",
          "type": "string"
        }
      ]
    });

    link.addNode("${path}/delete", {
      r"$name": "Delete",
      r"$invokable": "write",
      r"$is": "delete"
    });
  }

  @override
  onRemoving() {
    if (database != null) {
      database.close();
    }
  }
}

class WatchGroupNode extends SimpleNode {
  DatabaseNode db;
  String _watchName;

  WatchGroupNode(String path) : super(path, link.provider);

  @override
  onCreated() async {
    var p = new Path(path);
    db = link[p.parentPath];
    _watchName = configs[r"$name"];

    if (_watchName == null) {
      _watchName = NodeNamer.decodeName(p.name);
    }

    if (db.database == null) {
      Completer c = new Completer();
      db.onDatabaseReady.add(c.complete);
      await c.future;
    }

    link.addNode("${path}/addWatchPath", {
      r"$name": "Add Watch Path",
      r"$invokable": "write",
      r"$is": "addWatchPath",
      r"$params": [
        {
          "name": "Path",
          "type": "string"
        }
      ]
    });

    link.addNode("${path}/delete", {
      r"$name": "Delete",
      r"$invokable": "write",
      r"$is": "delete"
    });

    link.addNode("${path}/purge", {
      r"$name": "Purge",
      r"$invokable": "write",
      r"$params": [
        {
          "name": "timeRange",
          "type": "string",
          "editor": "daterange"
        }
      ],
      r"$is": "purgeGroup"
    });

    db.database.addWatchGroupExtensions(this);
  }

  Stream<ValuePair> fetchHistory(String path, TimeRange range) {
    return db.database.fetchHistory(name, path, range);
  }

  Future storeValues(List<ValueEntry> entries) {
    return db.database.store(entries);
  }
}

class ValueEntry {
  final String group;
  final String path;
  final String timestamp;
  final dynamic value;

  ValueEntry(this.group, this.path, this.timestamp, this.value);

  ValuePair asPair() {
    return new ValuePair(timestamp, value);
  }

  DateTime get time => DateTime.parse(timestamp);
}

TimeRange parseTimeRange(String input) {
  TimeRange tr;
  if (input != null) {
    List<String> l = input.split("/");
    DateTime start = DateTime.parse(l[0]);
    DateTime end = DateTime.parse(l[1]);

    tr = new TimeRange(start, end);
  }
  return tr;
}

HistorianAdapter historian;

historianMain(List<String> args, String name, HistorianAdapter adapter) async {
  historian = adapter;
  link = new LinkProvider(
    args,
    "${name}-",
    isRequester: true,
    autoInitialize: false,
    nodes: {
      "addDatabase": {
        r"$name": "Add Database",
        r"$invokable": "write",
        r"$params": [
          {
            "name": "Name",
            "type": "string",
            "placeholder": "HistoryData"
          }
        ]
          ..addAll(adapter.getCreateDatabaseParameters()),
        r"$is": "addDatabase"
      }
    },
    profiles: {
      "createWatchGroup": (String path) => new CreateWatchGroupNode(path),
      "addDatabase": (String path) => new AddDatabaseNode(path),
      "addWatchPath": (String path) => new AddWatchPathNode(path),
      "watchGroup": (String path) => new WatchGroupNode(path),
      "watchPath": (String path) => new WatchPathNode(path),
      "database": (String path) => new DatabaseNode(path),
      "delete": (String path) => new DeleteActionNode.forParent(
        path, link.provider as MutableNodeProvider, onDelete: () {
        link.save();
      }),
      "purgePath": (String path) => new PurgePathNode(path),
      "purgeGroup": (String path) => new PurgeGroupNode(path)
    },
    encodePrettyJson: true
  );
  link.init();
  link.connect();
}
