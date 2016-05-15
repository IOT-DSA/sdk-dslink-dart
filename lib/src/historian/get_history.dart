part of dslink.historian;

class GetHistoryNode extends SimpleNode {
  GetHistoryNode(String path) : super(path, _link.provider) {
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
      },
      {
        "name": "Batch Size",
        "type": "number",
        "default": 0
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
    RollupFactory rollupFactory = _rollups[rollupName];
    Rollup rollup = rollupFactory == null ? null : rollupFactory();
    Duration interval = new Duration(
      milliseconds: parseInterval(params["Interval"]));
    num batchSize = params["Batch Size"];

    if (batchSize == null) {
      batchSize = 0;
    }

    int batchCount = batchSize.toInt();

    TimeRange tr = parseTimeRange(range);
    if (params["Real Time"] == true) {
      tr = new TimeRange(tr.start, null);
    }

    try {
      Stream<ValuePair> pairs = await calculateHistory(
        tr,
        interval,
        rollup
      );

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
          if (count != 0 && count == batchCount) {
            yield buffer;
            buffer = [];
            count = 0;
          }
        }

        if (buffer.isNotEmpty) {
          yield buffer;
          buffer.length = 0;
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Stream<ValuePair> fetchHistoryData(TimeRange range) {
    var p = new Path(path);
    var mn = p.parent;
    WatchPathNode pn = _link[mn.path];

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
