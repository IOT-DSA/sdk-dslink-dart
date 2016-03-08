part of dslink.nodes;

class DsaJsonNode extends SimpleNode {
  DsaJsonNode(String path, [SimpleNodeProvider provider]) :
      super(path, provider);

  dynamic _json;

  void init(value) {
    load(buildNodeMap(value));
    _json = value;
  }

  void updateJsonValue(input) {
    if (input is! Map) {
      updateValue(input);
      _json = input;

      String type = _guessType(input);

      String lastType = configs[r"$type"];

      if (lastType != type) {
        configs[r"$type"] = type;
        updateList(r"$type");
      }

      return;
    }

    clearValue();
    JsonDiff.JsonDiffer differ = new JsonDiff.JsonDiffer(
      JSON.encode(_json),
      JSON.encode(input)
    );

    JsonDiff.DiffNode fullDiff = differ.diff();

    void apply(JsonDiff.DiffNode diff, DsaJsonNode node) {
      for (String key in diff.added.keys) {
        var name = NodeNamer.createName(key);
        provider.addNode(
          "${node.path}/${name}",
          buildNodeMap(diff.added[key])
        );
        node.updateList(r"$is");
      }

      for (String key in diff.removed.keys) {
        var name = NodeNamer.createName(key);

        provider.removeNode("${node.path}/${name}");
      }

      for (String key in diff.changed.keys) {
        var name = NodeNamer.createName(key);

        DsaJsonNode child = node.getChild(name);

        if (child == null) {
          child = provider.addNode(
            "${node.path}/${name}",
            buildNodeMap(diff.changed[key][1])
          );
        } else {
          child.updateJsonValue(diff.changed[key][1]);
        }
      }

      for (String key in diff.node.keys) {
        var name = NodeNamer.createName(key);

        DsaJsonNode child = node.getChild(name);

        if (child == null) {
          child = provider.addNode("${node.path}/${name}", buildNodeMap({}));
        }

        apply(diff.node[key], child);
      }
    }

    apply(fullDiff, this);

    _json = input;
  }

  @override
  void load(Map m) {
    super.load(m);

    if (m["?json"] != null) {
      init(m["?json"]);
    }

    if (m["?_json"] != null) {
      updateJsonValue(m["?_json"]);
    }
  }

  @override
  Map save() {
    var data = super.save();
    data["?json"] = _json;
    return data;
  }

  static String _guessType(input) {
    if (input is String) {
      return "string";
    } else if (input is num) {
      return "number";
    } else if (input is bool) {
      return "bool";
    } else {
      return "dynamic";
    }
  }

  static Map buildNodeMap(input) {
    Map create(value) {
      if (value is Map) {
        var m = {
          r"$is": "json"
        };

        for (String key in value.keys) {
          m[NodeNamer.createName(key)] = create(value[key]);
        }

        return m;
      } else if (value is List && value.every((e) => e is Map || e is List)) {
        var m = {};
        for (var i = 0; i < value.length; i++) {
          m[i.toString()] = create(value[i]);
        }
        return m;
      } else {
        return {
          r"$is": "json",
          r"$type": _guessType(value),
          "?_json": value
        };
      }
    }

    return create(input);
  }
}
