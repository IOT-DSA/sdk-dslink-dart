library dslink.test.common.json;

import "dart:convert";

import "package:test/test.dart";
import "package:dslink/utils.dart" show Base64, ByteDataUtil, DsCodec, DsJson;

void main() {
  group("JSON", jsonTests);
}

void jsonTests() {
  test("successfully decodes valid inputs", () {
    for (var i = 0; i < JSON_STRINGS.length; i++) {
      var input = JSON_STRINGS[i];
      var output = JSON_OBJECTS[i];

      expect(DsJson.decode(input), equals(output));
    }
  });

  test("successfully encodes valid objects", () {
    for (var i = 0; i < JSON_STRINGS.length; i++) {
      var input = JSON_OBJECTS[i];
      var output = JSON_STRINGS[i];

      expect(DsJson.encode(input, pretty: true), equals(output.trim()));
    }
  });

  test("successfully decodes binary frame inputs", () {
    var input = """
    {
      "data": "\\u001Bbytes:${Base64.encode(UTF8.encode("Hello World"))}"
    }
    """;
    DsCodec codec = DsCodec.getCodec('json');
    var output = codec.decodeStringFrame(input);
    var data = output["data"];
    expect(UTF8.decode(ByteDataUtil.toUint8List(data)), equals("Hello World"));
  });
}

final List<String> JSON_STRINGS = [
  """
{
  "responses": [
    {
      "rid": 0,
      "updates": [
        {
          "ts": "2015-08-17T18:31:49.856+00:00",
          "value": 1,
          "sid": 5,
          "count": 36332523,
          "sum": 18165428,
          "max": 1,
          "min": 0
        },
        {
          "ts": "2015-08-17T18:31:49.856+00:00",
          "value": 1,
          "sid": 6,
          "count": 36332523,
          "sum": 18165428,
          "max": 1,
          "min": 0
        },
        {
          "ts": "2015-08-17T18:31:49.856+00:00",
          "value": 1,
          "sid": 7,
          "count": 36332523,
          "sum": 18165428,
          "max": 1,
          "min": 0
        },
        {
          "ts": "2015-08-17T18:31:49.856+00:00",
          "value": 1,
          "sid": 8,
          "count": 36332523,
          "sum": 18165428,
          "max": 1,
          "min": 0
        },
        {
          "ts": "2015-08-17T18:31:49.856+00:00",
          "value": 1,
          "sid": 9,
          "count": 36332523,
          "sum": 18165428,
          "max": 1,
          "min": 0
        },
        {
          "ts": "2015-08-17T18:31:49.856+00:00",
          "value": 1,
          "sid": 10,
          "count": 36332523,
          "sum": 18165428,
          "max": 1,
          "min": 0
        },
        {
          "ts": "2015-08-17T18:31:49.856+00:00",
          "value": 1,
          "sid": 11,
          "count": 36332523,
          "sum": 18165428,
          "max": 1,
          "min": 0
        },
        {
          "ts": "2015-08-17T18:31:49.856+00:00",
          "value": 1,
          "sid": 12,
          "count": 36332523,
          "sum": 18165428,
          "max": 1,
          "min": 0
        },
        {
          "ts": "2015-08-17T18:31:49.856+00:00",
          "value": 1,
          "sid": 13,
          "count": 36332523,
          "sum": 18165428,
          "max": 1,
          "min": 0
        },
        {
          "ts": "2015-08-17T18:31:49.856+00:00",
          "value": 1,
          "sid": 14,
          "count": 36332523,
          "sum": 18165428,
          "max": 1,
          "min": 0
        }
      ]
    }
  ],
  "msg": 624
}
  """
];

final List<dynamic> JSON_OBJECTS = [
  {
    "responses": [
      {
        "rid": 0,
        "updates": [
          {
            "ts": "2015-08-17T18:31:49.856+00:00",
            "value": 1,
            "sid": 5,
            "count": 36332523,
            "sum": 18165428,
            "max": 1,
            "min": 0
          },
          {
            "ts": "2015-08-17T18:31:49.856+00:00",
            "value": 1,
            "sid": 6,
            "count": 36332523,
            "sum": 18165428,
            "max": 1,
            "min": 0
          },
          {
            "ts": "2015-08-17T18:31:49.856+00:00",
            "value": 1,
            "sid": 7,
            "count": 36332523,
            "sum": 18165428,
            "max": 1,
            "min": 0
          },
          {
            "ts": "2015-08-17T18:31:49.856+00:00",
            "value": 1,
            "sid": 8,
            "count": 36332523,
            "sum": 18165428,
            "max": 1,
            "min": 0
          },
          {
            "ts": "2015-08-17T18:31:49.856+00:00",
            "value": 1,
            "sid": 9,
            "count": 36332523,
            "sum": 18165428,
            "max": 1,
            "min": 0
          },
          {
            "ts": "2015-08-17T18:31:49.856+00:00",
            "value": 1,
            "sid": 10,
            "count": 36332523,
            "sum": 18165428,
            "max": 1,
            "min": 0
          },
          {
            "ts": "2015-08-17T18:31:49.856+00:00",
            "value": 1,
            "sid": 11,
            "count": 36332523,
            "sum": 18165428,
            "max": 1,
            "min": 0
          },
          {
            "ts": "2015-08-17T18:31:49.856+00:00",
            "value": 1,
            "sid": 12,
            "count": 36332523,
            "sum": 18165428,
            "max": 1,
            "min": 0
          },
          {
            "ts": "2015-08-17T18:31:49.856+00:00",
            "value": 1,
            "sid": 13,
            "count": 36332523,
            "sum": 18165428,
            "max": 1,
            "min": 0
          },
          {
            "ts": "2015-08-17T18:31:49.856+00:00",
            "value": 1,
            "sid": 14,
            "count": 36332523,
            "sum": 18165428,
            "max": 1,
            "min": 0
          }
        ]
      }
    ],
    "msg": 624
  }
];
