part of dslink.utils;

Uint8List mergeBytes(List<Uint8List> bytesList) {
  int totalLen = 0;
  for (Uint8List bytes in bytesList) {
    totalLen += bytes.length;
  }
  Uint8List output = new Uint8List(totalLen);
  int pos = 0;
  for (Uint8List bytes in bytesList) {
    output.setAll(pos, bytes);
    pos += bytes.length;
  }
  return output;
}