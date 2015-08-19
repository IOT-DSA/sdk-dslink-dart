part of dslink.utils;

class DSLinkJSON {
  Map _json;

  Map get json => _json;

  String name;
  String version;
  String description;
  String main;
  Map<String, dynamic> engines = {};
  Map<String, Map<String, dynamic>> configs = {};
  List<String> getDependencies = [];

  DSLinkJSON();

  factory DSLinkJSON.from(Map<String, dynamic> map) {
    var j = new DSLinkJSON();
    j._json = map;
    j.name = map["name"];
    j.version = map["version"];
    j.description = map["description"];
    j.main = map["main"];
    j.engines = map["engines"];
    j.configs = map["configs"];
    j.getDependencies = map["getDependencies"];
    return j;
  }

  void verify() {
    if (name == null) {
      throw new Exception("DSLink Name is required.");
    }

    if (main == null) {
      throw new Exception("DSLink Main Script is required.");
    }
  }

  Map save() {
    verify();

    var map = new Map<String, dynamic>.from(_json != null ? _json : {});
    map["name"] = name;
    map["version"] = version;
    map["description"] = description;
    map["main"] = main;
    map["engines"] = engines;
    map["configs"] = configs;
    map["getDependencies"] = getDependencies;
    for (var key in map.keys.toList()) {
      if (map[key] == null) {
        map.remove(key);
      }
    }
    return map;
  }
}
