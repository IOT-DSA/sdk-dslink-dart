part of dslink.common;

class DsNode {
  /// absoulte node path from the responder root.
  final String path;

  /// node name or custom name defined in $name
  String name;

  DsNode profile;

  /// mixins are stored in a reverse order as the mixin string is defined
  List<DsNode> mixins;
  Map<String, String> attributes = {};

  DsNode(this.path);

  String getAttribute(String name) {
    if (attributes.containsKey(name)) {
      return attributes[name];
    }

    if (mixins != null) {
      for (var mixin in mixins) {
        if (mixin.attributes.containsKey(name)) {
          return mixin.attributes[name];
        }
      }
    }

    if (profile != null && profile.attributes.containsKey(name)) {
      return profile.attributes[name];
    }
    return null;
  }

  Map<String, Object> configs = {};

  Object getConfig(String name) {
    if (configs.containsKey(name)) {
      return configs[name];
    }
    if (mixins != null) {
      for (var mixin in mixins) {
        if (mixin.configs.containsKey(name)) {
          return mixin.configs[name];
        }
      }
    }
    if (profile != null && profile.configs.containsKey(name)) {
      return profile.configs[name];
    }
    return null;
  }

  Map<String, DsNode> _children = {};

  DsNode getChild(String name) {
    if (_children.containsKey(name)) {
      return _children[name];
    }

    // mixin is never allowed to change
    if (profile != null && profile.configs.containsKey(name)) {
      return profile.configs[name];
    }
    return null;
  }
}
