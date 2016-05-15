part of dslink.historian;

class DatabaseNode extends SimpleNode {
  Map config;
  HistorianDatabaseAdapter database;
  List<Function> onDatabaseReady = [];

  DatabaseNode(String path) : super(path);

  @override
  void onCreated() {
    new Future(() async {
      config = configs[r"$$db_config"];
      while (removed != true) {
        try {
          database = await _historian.getDatabase(config);
          while (onDatabaseReady.isNotEmpty) {
            onDatabaseReady.removeAt(0)();
          }
          break;
        } catch (e, stack) {
          logger.severe(
            "Failed to connect to database for ${path}",
            e,
            stack
          );
          await new Future.delayed(const Duration(seconds: 5));
        }
      }

      if (removed == true) {
        try {
          await database.close();
        } catch (e) {}
        return;
      }

      _link.addNode("${path}/createWatchGroup", {
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

      _link.addNode("${path}/delete", {
        r"$name": "Delete",
        r"$invokable": "write",
        r"$is": "delete"
      });
    });
  }

  @override
  onRemoving() {
    if (database != null) {
      database.close();
    }
  }
}

class WatchPathNode extends SimpleNode {
  String valuePath;
  WatchGroupNode group;
  bool isPublishOnly = false;

  WatchPathNode(String path) : super(path);

  @override
  onCreated() async {
    String rp = configs[r"$path"];

    if (rp == null) {
      rp = configs[r"$value_path"];
    }

    if (configs[r"$publish"] == true) {
      isPublishOnly = true;
    }

    valuePath = rp;
    group = _link[new Path(path).parentPath];

    String groupName = group._watchName;

    _link.addNode("${path}/lwv", {
      r"$name": "Last Written Value",
      r"$type": "dynamic"
    });

    _link.addNode("${path}/startDate", {
      r"$name": "Start Date",
      r"$type": "string"
    });

    _link.addNode("${path}/endDate", {
      r"$name": "End Date",
      r"$type": "string"
    });

    if (children["enabled"] == null) {
      _link.addNode("${path}/enabled", {
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

    HistorySummary summary = await group.db.database.getSummary(
      groupName,
      valuePath
    );

    if (summary.first != null) {
      _link.updateValue("${path}/startDate", summary.first.timestamp);
      isStartDateFilled = true;
    }

    if (summary.last != null) {
      ValueUpdate update = new ValueUpdate(
        summary.last.value,
        ts: summary.last.timestamp
      );
      _link.updateValue("${path}/lwv", update);
      updateValue(update);
    }

    timer = Scheduler.safeEvery(const Duration(seconds: 1), () async {
      await storeBuffer();
    });

    var ghn = new GetHistoryNode("${path}/getHistory");
    addChild("getHistory", ghn);
    (_link.provider as SimpleNodeProvider).setNode(ghn.path, ghn);
    updateList("getHistory");

    _link.addNode("${path}/purge", {
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

    _link.addNode("${path}/delete", {
      r"$name": "Delete",
      r"$invokable": "write",
      r"$is": "delete"
    });

    _link.onValueChange("${path}/enabled").listen((ValueUpdate update) {
      if (update.value == true) {
        sub();
      } else {
        if (valueSub != null) {
          valueSub.cancel();
          valueSub = null;
        }
      }
    });

    if (_link.val("${path}/enabled") == true) {
      sub();
    }

    group.db.database.addWatchPathExtensions(this);
  }

  ReqSubscribeListener valueSub;

  sub() {
    if (!isPublishOnly) {
      if (valueSub != null) {
        valueSub.cancel();
        valueSub = null;
      }

      valueSub = _link.requester.subscribe(valuePath, (ValueUpdate update) {
        doUpdate(update);
      });
    }
  }

  void doUpdate(ValueUpdate update) {
    updateValue(update);
    buffer.add(update);
  }

  ValueEntry asValueEntry(ValueUpdate update) {
    return new ValueEntry(group._watchName, valuePath, update.ts, update.value);
  }

  bool isStartDateFilled = false;

  storeBuffer() async {
    List<ValueEntry> entries = buffer.map(asValueEntry).toList();

    if (entries.isNotEmpty) {
      try {
        if (!isStartDateFilled) {
          _link.updateValue("${path}/startDate", entries.first.timestamp);
        }

        _link.updateValue("${path}/lwv", entries.last.value);
        _link.updateValue("${path}/endDate", entries.last.timestamp);
      } catch (e) {
      }
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

    while (onRemoveCallbacks.isNotEmpty) {
      onRemoveCallbacks.removeAt(0)();
    }
  }

  @override
  Map save() {
    var out = super.save();
    out.remove("lwv");
    out.remove("startDate");
    out.remove("endDate");
    out.remove("getHistory");
    out.remove("publish");

    while (onSaveCallbacks.isNotEmpty) {
      onSaveCallbacks.removeAt(0)(out);
    }

    return out;
  }

  List<Function> onSaveCallbacks = [];
  List<Function> onRemoveCallbacks = [];

  List<ValueUpdate> buffer = [];
  Disposable timer;

  Stream<ValuePair> fetchHistory(TimeRange range) {
    return group.fetchHistory(valuePath, range);
  }
}

class WatchGroupNode extends SimpleNode {
  DatabaseNode db;
  String _watchName;

  WatchGroupNode(String path) : super(path, _link.provider);

  @override
  onCreated() {
    var p = new Path(path);
    db = _link[p.parentPath];
    _watchName = configs[r"$name"];

    if (_watchName == null) {
      _watchName = NodeNamer.decodeName(p.name);
    }

    _link.addNode("${path}/addWatchPath", {
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

    _link.addNode("${path}/publish", {
      r"$name": "Publish",
      r"$invokable": "write",
      r"$is": "publishValue",
      r"$params": [
        {
          "name": "Path",
          "type": "string"
        },
        {
          "name": "Value",
          "type": "dynamic"
        },
        {
          "name": "Timestamp",
          "type": "string"
        }
      ]
    });

    _link.addNode("${path}/delete", {
      r"$name": "Delete",
      r"$invokable": "write",
      r"$is": "delete"
    });

    _link.addNode("${path}/purge", {
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

    new Future(() async {
      if (db.database == null) {
        Completer c = new Completer();
        db.onDatabaseReady.add(c.complete);
        await c.future;
      }

      db.database.addWatchGroupExtensions(this);
    });
  }

  @override
  onRemoving() {
    while (onRemoveCallbacks.isNotEmpty) {
      onRemoveCallbacks.removeAt(0)();
    }
    super.onRemoving();
  }

  Stream<ValuePair> fetchHistory(String path, TimeRange range) {
    return db.database.fetchHistory(name, path, range);
  }

  Future storeValues(List<ValueEntry> entries) {
    return db.database.store(entries);
  }

  List<Function> onRemoveCallbacks = [];
}

