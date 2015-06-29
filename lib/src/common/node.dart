part of dslink.common;

class Node {
  /// absoulte node path from the responder root.

  Node profile;

  Map<String, Object> attributes = {};

  Node();

  Object getAttribute(String name) {
    if (attributes.containsKey(name)) {
      return attributes[name];
    }

    if (profile != null && profile.attributes.containsKey(name)) {
      return profile.attributes[name];
    }
    return null;
  }

  Map<String, Object> configs = {r'$is': 'node'};

  Object getConfig(String name) {
    if (configs.containsKey(name)) {
      return configs[name];
    }

    if (profile != null && profile.configs.containsKey(name)) {
      return profile.configs[name];
    }
    return null;
  }

  Map<String, Node> children = {};

  void addChild(String name, Node node) {
    children[name] = node;
  }

  /// remove node and return name
  String removeChild(dynamic input) {
    if (input is String) {
      children.remove(getChild(input));
      return input;
    } else if (input is Node) {
      children.remove(input);
    } else {
      throw new Exception("Invalid Input");
    }
    return null;
  }

  Node getChild(String name) {
    if (children.containsKey(name)) {
      return children[name];
    }

    if (profile != null && profile.children.containsKey(name)) {
      return profile.children[name];
    }
    return null;
  }

  Object get(String name) {
    if (name.startsWith(r'$')) {
      return getConfig(name);
    }
    if (name.startsWith('@')) {
      return getAttribute(name);
    }
    return getChild(name);
  }

  void forEachChild(void callback(String, Node)) {
    children.forEach(callback);
    if (profile != null) {
      profile.children.forEach((String str, Node n) {
        if (!children.containsKey(str)) {
          callback(str, n);
        }
      });
    }
  }

  // get a simple map for data listed in parent's children property
  Map getSimpleMap() {
    Map rslt = {};
    if (configs.containsKey(r'$is')) {
      rslt[r'$is'] = configs[r'$is'];
    }
    if (configs.containsKey(r'$type')) {
      rslt[r'$type'] = configs[r'$type'];
    }
    if (configs.containsKey(r'$name')) {
      rslt[r'$name'] = configs[r'$name'];
    }
    if (configs.containsKey(r'$invokable')) {
      rslt[r'$invokable'] = configs[r'$invokable'];
    }
    if (configs.containsKey(r'$writable')) {
      rslt[r'$writable'] = configs[r'$writable'];
    }
    // TODO add permission of current requester
    return rslt;
  }
}

/// Util class for ds node path and config/attribute path
class Path {
  static final RegExp invalidChar = new RegExp(r'[\.\\\?\*:|"<>]');
  static final RegExp invalidNameChar = new RegExp(r'[\/\.\\\?\*:|"<>]');

  static Path getValidPath(Object path, [String basePath]) {
    if (path is String) {
      Path p = new Path(path);
      if (p.valid) {
        return p..mergeBasePath(basePath);
      }
    }
    return null;
  }

  static Path getValidNodePath(Object path, [String basePath]) {
    if (path is String) {
      Path p = new Path(path);
      if (p.valid && p.isNode) {
        return p..mergeBasePath(basePath);
      }
    }
    return null;
  }

  static Path getValidAttributePath(Object path, [String basePath]) {
    if (path is String) {
      Path p = new Path(path);
      if (p.valid && p.isAttribute) {
        return p..mergeBasePath(basePath);
      }
    }
    return null;
  }

  static Path getValidConfigPath(Object path, [String basePath]) {
    if (path is String) {
      Path p = new Path(path);
      if (p.valid && p.isConfig) {
        return p..mergeBasePath(basePath);
      }
    }
    return null;
  }

  String path;
  String parentPath;

  /// root node has the name '/';
  String name;
  bool valid = true;

  Path(this.path) {
    _parse();
  }

  void _parse() {
    if (path == '' || path.contains(invalidChar) || path.contains('//')) {
      valid = false;
    }
    if (path == '/') {
      valid = true;
      name = '/';
      parentPath = '';
      return;
    }
    if (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    int pos = path.lastIndexOf('/');
    if (pos < 0) {
      name = path;
      parentPath = '';
    } else if (pos == 0) {
      parentPath = '/';
      name = path.substring(1);
    } else {
      parentPath = path.substring(0, pos);
      name = path.substring(pos + 1);
      if (parentPath.contains(r'/$') || parentPath.contains('/@')) {
        // parent path can't be attribute or config
        valid = false;
      }
    }
  }

  bool get absolute {
    return name == '/' || parentPath.startsWith('/');
  }

  bool get isRoot {
    return name == '/';
  }

  bool get isConfig {
    return name.startsWith(r'$');
  }

  bool get isAttribute {
    return name.startsWith(r'@');
  }

  bool get isNode {
    return !name.startsWith(r'@') && !name.startsWith(r'$');
  }

  void mergeBasePath(String base, [bool force = false]) {
    if (base == null) {
      return;
    }
    if (!absolute) {
      if (parentPath == '') {
        parentPath = base;
      } else {
        parentPath = '$base/$parentPath';
      }
      path = '$parentPath/$name';
    } else if (force) {
      // apply base path on a absolute path
      if (name == '') {
        // map the root path
        path = base;
        _parse();
      } else {
        parentPath = '$base$parentPath';
        path = '$parentPath/$name';
      }
    }
  }
}
