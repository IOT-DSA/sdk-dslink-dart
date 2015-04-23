part of dslink.utils;

abstract class DsJson{
  static DsJson instance = new DsJsonCodecImpl();
  static String encode(Object val) {
    return instance.encodeJson(val);
  }
  static Object decode(String str) {
    return instance.decodeJson(str);
  }
  
  String encodeJson(Object val);
  Object decodeJson(String str);
  
}

class DsJsonCodecImpl implements DsJson{
  
  Object decodeJson(String str) {
    return JSON.decode(str);
  }

  String encodeJson(Object val) {
    return JSON.encode(val);
  }
}