part of dslink.utils;

/// difference from crypto lib CryptoUtils.bytesToBase64:
/// 1) default to url filename safe base64
/// 2) allow byte array to have negative int -128 ~ -1
/// 3) custom line size and custom padding space
class Base64 {
  static const int PAD = 61; // '='
  static const int CR = 13; // '\r'
  static const int LF = 10; // '\n'
  static const int SP = 32; // ' '
  static const int PLUS = 43; // '+'
  static const int SLASH = 47; // '/'

  static const String _encodeTable =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

  /// Lookup table used for finding Base 64 alphabet index of a given byte.
  /// -2 : Outside Base 64 alphabet.
  /// -1 : '\r' or '\n'
  /// 0 : = (Padding character).
  /// >=0 : Base 64 alphabet index of given byte.
  static final List<int> _decodeTable = (() {
    List<int> table = new List<int>(256);
    table.fillRange(0, 256, -2);
    List<int> charCodes = _encodeTable.codeUnits;
    int len = charCodes.length;
    for (int i = 0; i < len; ++i) {
      table[charCodes[i]] = i;
    }
    table[PLUS] = 62;
    table[SLASH] = 63;
    table[CR] = -1;
    table[LF] = -1;
    table[SP] = -1;
    table[LF] = -1;
    table[PAD] = 0;
    return table;
  })();

  static String encodeString(String content,
      [int lineSize = 0, int paddingSpace = 0]) {
    return Base64.encode(fastEncodeUtf8(content), lineSize, paddingSpace);
  }

  static String decodeString(String input) {
    return const Utf8Decoder().convert(decode(input));
  }

  static String encode(List<int> bytes,
      [int lineSize = 0, int paddingSpace = 0]) {
    int len = bytes.length;
    if (len == 0) {
      return "";
    }
    // Size of 24 bit chunks.
    final int remainderLength = len.remainder(3);
    final int chunkLength = len - remainderLength;
    // Size of base output.
    int outputLen =
        ((len ~/ 3) * 4) + ((remainderLength > 0) ? 4 : 0) + paddingSpace;
    // Add extra for line separators.
    int lineSizeGroup = lineSize >> 2;
    if (lineSizeGroup > 0) {
      outputLen +=
          ((outputLen - 1) ~/ (lineSizeGroup << 2)) * (1 + paddingSpace);
    }
    List<int> out = new List<int>(outputLen);

    // Encode 24 bit chunks.
    int j = 0, i = 0, c = 0;
    for (int i = 0; i < paddingSpace; ++i) {
      out[j++] = SP;
    }
    while (i < chunkLength) {
      int x = (((bytes[i++] % 256) << 16) & 0xFFFFFF) |
          (((bytes[i++] % 256) << 8) & 0xFFFFFF) |
          (bytes[i++] % 256);
      out[j++] = _encodeTable.codeUnitAt(x >> 18);
      out[j++] = _encodeTable.codeUnitAt((x >> 12) & 0x3F);
      out[j++] = _encodeTable.codeUnitAt((x >> 6) & 0x3F);
      out[j++] = _encodeTable.codeUnitAt(x & 0x3f);
      // Add optional line separator for each 76 char output.
      if (lineSizeGroup > 0 && ++c == lineSizeGroup && j < outputLen - 2) {
        out[j++] = LF;
        for (int i = 0; i < paddingSpace; ++i) {
          out[j++] = SP;
        }
        c = 0;
      }
    }

    // If input length if not a multiple of 3, encode remaining bytes and
    // add padding.
    if (remainderLength == 1) {
      int x = bytes[i] % 256;
      out[j++] = _encodeTable.codeUnitAt(x >> 2);
      out[j++] = _encodeTable.codeUnitAt((x << 4) & 0x3F);
//     out[j++] = PAD;
//     out[j++] = PAD;
      return new String.fromCharCodes(out.sublist(0, outputLen - 2));
    } else if (remainderLength == 2) {
      int x = bytes[i] % 256;
      int y = bytes[i + 1] % 256;
      out[j++] = _encodeTable.codeUnitAt(x >> 2);
      out[j++] = _encodeTable.codeUnitAt(((x << 4) | (y >> 4)) & 0x3F);
      out[j++] = _encodeTable.codeUnitAt((y << 2) & 0x3F);
//     out[j++] = PAD;
      return new String.fromCharCodes(out.sublist(0, outputLen - 1));
    }

    return new String.fromCharCodes(out);
  }

  static Uint8List decode(String input) {
    if (input == null) {
      return null;
    }
    int len = input.length;
    if (len == 0) {
      return new Uint8List(0);
    }

    // Count '\r', '\n' and illegal characters, For illegal characters,
    // throw an exception.
    int extrasLen = 0;
    for (int i = 0; i < len; i++) {
      int c = _decodeTable[input.codeUnitAt(i)];
      if (c < 0) {
        extrasLen++;
        if (c == -2) {
          return null;
        }
      }
    }

    int lenmis = (len - extrasLen) % 4;
    if (lenmis == 2) {
      input = '$input==';
      len += 2;
    } else if (lenmis == 3) {
      input = '$input=';
      len += 1;
    } else if (lenmis == 1) {
      return null;
    }

    // Count pad characters.
    int padLength = 0;
    for (int i = len - 1; i >= 0; i--) {
      int currentCodeUnit = input.codeUnitAt(i);
      if (_decodeTable[currentCodeUnit] > 0) break;
      if (currentCodeUnit == PAD) padLength++;
    }
    int outputLen = (((len - extrasLen) * 6) >> 3) - padLength;
    Uint8List out = new Uint8List(outputLen);

    for (int i = 0, o = 0; o < outputLen;) {
      // Accumulate 4 valid 6 bit Base 64 characters into an int.
      int x = 0;
      for (int j = 4; j > 0;) {
        int c = _decodeTable[input.codeUnitAt(i++)];
        if (c >= 0) {
          x = ((x << 6) & 0xFFFFFF) | c;
          j--;
        }
      }
      out[o++] = x >> 16;
      if (o < outputLen) {
        out[o++] = (x >> 8) & 0xFF;
        if (o < outputLen) out[o++] = x & 0xFF;
      }
    }
    return out;
  }
}
