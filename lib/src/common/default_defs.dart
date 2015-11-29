part of dslink.common;

Map defaultProfileMap = {
  "node": {},
  "static": {},
  "getHistory": {
    r"$invokable": "read",
    r"$result": "table",
    r"$params": [
      {"name": "Timerange", "type": "string", "editor": "daterange"},
      {
        "name": "Interval",
        "type": "enum",
        "editor": buildEnumType([
          "default",
          "none",
          "1Y",
          "3N",
          "1N",
          "1W",
          "1D",
          "12H",
          "6H",
          "4H",
          "3H",
          "2H",
          "1H",
          "30M",
          "15M",
          "10M",
          "5M",
          "1M",
          "30S",
          "15S",
          "10S",
          "5S",
          "1S"
        ])
      },
      {
        "name": "Rollup",
        "type": buildEnumType(
            ["avg", "min", "max", "sum", "first", "last", "count"])
      }
    ],
    r"$columns": [
      {"name": "timestamp", "type": "time"},
      {"name": "value", "type": "dynamic"}
    ]
  },
  "broker": {
    "userNode": {
      "addChild": {
        r"$invokable": "config",
        r"$params": [{"name": "Name", "type": "string"}]
      },
      "addLink": {
        r"$invokable": "config",
        r"$params": [
          {"name": "Name", "type": "string"},
          {"name": "Id", "type": "string"}
        ]
      },
      "remove": {r"$invokable": "config"}
    },
    "userRoot": {
      "addChild": {
        r"$invokable": "config",
        r"$params": [{"name": "Name", "type": "string"}]
      },
      "addLink": {
        r"$invokable": "config",
        r"$params": [
          {"name": "Name", "type": "string"},
          {"name": "Id", "type": "string"}
        ]
      }
    },
    "dataNode": {
      "addNode": {
        r"$invokable": "write",
        r"$params": [{"name": "Name", "type": "string"}]
      },
      "addValue": {
        r"$invokable": "write",
        r"$params": [
          {"name": "Name", "type": "string"},
          {
            "name": "Type",
            "type": "enum[string,number,bool,array,map,binary,dynamic]"
          },
          {
            "name": "Editor",
            "type": "enum[none,textarea,password,daterange,date]"
          }
        ]
      },
      "deleteNode": {
        r"$invokable": "write",
        r"$params": [{"name": "Recursive", "type": "bool"}]
      }
    },
    "dataRoot": {
      "addNode": {
        r"$invokable": "write",
        r"$params": [{"name": "Name", "type": "string"}]
      },
      "addValue": {
        r"$invokable": "write",
        r"$params": [
          {"name": "Name", "type": "string"},
          {
            "name": "Type",
            "type": "enum[string,number,bool,array,map,binary,dynamic]"
          },
          {
            "name": "Editor",
            "type": "enum[none,textarea,password,daterange,date]"
          }
        ]
      }
    },
    "token": {"delete": {r"$invokable": "config", r"$params": []}},
    "tokenGroup": {
      "add": {
        r"$invokable": "config",
        r"$params": [
          {"name": "timeRange", "type": "string", "editor": "daterange"},
          {"name": "count", "type": "number"},
        ],
        r"$columns": [{"name": "tokenName", "type": "string"}]
      }
    }
  }
};
