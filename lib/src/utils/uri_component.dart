part of dslink.utils;

/// a decoder class to decode malformed url encoded string
class UriComponentDecoder {
  static const int _SPACE = 0x20;
  static const int _PERCENT = 0x25;
  static const int _PLUS = 0x2B;

  static String decode(String text) {
    List<int> codes = new List<int>();
    List<int> bytes = new List<int>();
    int len = text.length;
    for (int i = 0; i < len; i++) {
      var codeUnit = text.codeUnitAt(i);
      if (codeUnit == _PERCENT) {
        if (i + 3 > text.length) {
          bytes.add(_PERCENT);
          continue;
        }
        int hexdecoded = _hexCharPairToByte(text, i + 1);
        if (hexdecoded > 0) {
          bytes.add(hexdecoded);
          i += 2;
        } else {
          bytes.add(_PERCENT);
        }
      } else {
        if (!bytes.isEmpty) {
          codes.addAll(
            const Utf8Decoder(allowMalformed: true)
              .convert(bytes)
              .codeUnits);
          bytes.clear();
        }
        if (codeUnit == _PLUS) {
          codes.add(_SPACE);
        } else {
          codes.add(codeUnit);
        }
      }
    }

    if (!bytes.isEmpty) {
      codes.addAll(const Utf8Decoder()
        .convert(bytes)
        .codeUnits);
      bytes.clear();
    }
    return new String.fromCharCodes(codes);
  }

  static int _hexCharPairToByte(String s, int pos) {
    int byte = 0;
    for (int i = 0; i < 2; i++) {
      int charCode = s.codeUnitAt(pos + i);
      if (0x30 <= charCode && charCode <= 0x39) {
        byte = byte * 16 + charCode - 0x30;
      } else if ((charCode >= 0x41 && charCode <= 0x46) ||
        (charCode >= 0x61 && charCode <= 0x66)) {
        // Check ranges A-F (0x41-0x46) and a-f (0x61-0x66).
        charCode |= 0x20;
        byte = byte * 16 + charCode - 0x57;
      } else {
        return -1;
      }
    }
    return byte;
  }
}
