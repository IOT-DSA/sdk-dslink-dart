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


/// Util class for ds node path and config attribut path
class DsPath {
  static final RegExp invalidChar = new RegExp(r'[\.\/\\\?%\*:|"<>]');
  static DsPath getValidPath(Object path, [String basePath]) {
    if (path is String) {
      DsPath p = new DsPath(path);
      if (p.valid) {
        return p..mergeBasePath(basePath);
      }
    }
    return null;
  }
  static DsPath getValidNodePath(Object path, [String basePath]) {
    if (path is String) {
      DsPath p = new DsPath(path);
      if (p.valid && p.isNode) {
        return p..mergeBasePath(basePath);
      }
    }
    return null;
  }
  static DsPath getValidAttributePath(Object path, [String basePath]) {
    if (path is String) {
      DsPath p = new DsPath(path);
      if (p.valid && p.isAttribute) {
        return p..mergeBasePath(basePath);
      }
    }
    return null;
  }
  static DsPath getValidConfigPath(Object path, [String basePath]) {
    if (path is String) {
      DsPath p = new DsPath(path);
      if (p.valid && p.isConfig) {
        return p..mergeBasePath(basePath);
      }
    }
    return null;
  }
  String path;
  String parentPath;
  String name;
  bool valid = true;
  bool absolute;
  DsPath(this.path) {
    if (path == '' || path.contains(invalidChar) || path.contains('//')) {
      valid = false;
    }
    if (path == '/') {
      valid = true;
      name = '';
      return;
    }
    if (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    absolute = path.startsWith('/');
    int pos = path.lastIndexOf('/');
    if (pos < 0) {
      name = path;
    } else if (pos == 0) {
      parentPath = '/';
      name = path.substring(1);
    } else {
      parentPath = path.substring(0, pos);
      name = path.substring(0, pos + 1);
      if (parentPath.contains(r'/$') || parentPath.contains('/@')) {
        // parent path can't be attribute or config
        valid = false;
      }
    }
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
  
  void mergeBasePath(String base) {
    if (base == null) {
      return;
    }
    if (!absolute) {
      if (parentPath == null) {
        parentPath = base;
      } else {
        parentPath = base + '/' + parentPath;
      }
    }
    absolute = base.startsWith('/');
  }
}
