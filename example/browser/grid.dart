import "dart:html";

import "package:dslink/browser.dart";

LinkProvider link;
Requester r;

main() async {
  var brokerUrl = await BrowserUtils.fetchBrokerUrlFromPath("broker_url", "http://localhost:8080/conn");

  link = new LinkProvider(brokerUrl, "HtmlGrid-", isRequester: true, isResponder: false);
  await link.connect();

  r = link.requester;

  var dataNode = await r.getRemoteNode("/data");
  if (!dataNode.children.containsKey("grid")) {
    await r.invoke("/data/addValue", {
      "Name": "grid",
      "Type": "array"
    }).firstWhere((x) => x.streamStatus == StreamStatus.closed);

    var generateList = (i) => new List<bool>.generate(15, (x) => false);
    var list = new List<List<bool>>.generate(15, generateList);
    await r.set("/data/grid", list);
  }

  r.onValueChange("/data/grid").listen((ValueUpdate update) {
    if (update.value is! List) return;

    var isNew = _grid == null;

    loadGrid(update.value);

    if (isNew) {
      resizeGrid(15, 15);
    }
  });

  querySelector("#clear-btn").onClick.listen((e) {
    clearGrid();
  });
}

List<List<bool>> _grid = [];

resizeGrid(int width, int height) {
  List<List<bool>> grid = deepCopy(_grid);

  print(grid);

  grid.length = height;
  for (var i = 0; i < height; i++) {
    var row = grid[i];
    if (row == null) {
      row = grid[i] = new List<bool>();
    }

    row.length = width;
    for (var x = 0; x < width; x++) {
      if (row[x] == null) {
        row[x] = false;
      }
    }
  }

  _grid = grid;
  r.set("/data/grid", _grid);
}

deepCopy(input) {
  if (input is List) {
    return input.map(deepCopy).toList();
  }
  return input;
}

clearGrid() {
  for (var row in _grid) {
    row.fillRange(0, _grid.length, false);
  }
  r.set("/data/grid", _grid);
}

loadGrid(List<List<bool>> input) {
  _grid = input;

  var root = querySelector("#root");

  for (var i = 1; i <= input.length; i++) {
    List<bool> row = input[i - 1];

    DivElement rowe = querySelector("#row-${i}");
    if (rowe == null) {
      rowe = new DivElement();
      rowe.id = "row-${i}";
      rowe.classes.add("row");
      root.append(rowe);
    }

    for (var x = 1; x <= row.length; x++) {
      bool val = row[x - 1];
      DivElement cow = querySelector("#block-${i}-${x}");
      if (cow == null) {
        cow = new DivElement();
        cow.id = "block-${i}-${x}";
        cow.classes.add("block");
        cow.style.transition = "background-color 0.2s";
        cow.onClick.listen((e) {
          if (_grid[i - 1][x - 1]) {
            _grid[i - 1][x - 1] = false;
          } else {
            _grid[i - 1][x - 1] = true;
          }

          r.set("/data/grid", _grid);
        });

        cow.onMouseEnter.listen((e) {
          if (_grid[i - 1][x - 1] != true) {
            _grid[i - 1][x - 1] = null;
          }
          r.set("/data/grid", _grid);
        });

        cow.onMouseLeave.listen((e) {
          if (_grid[i - 1][x - 1] == null) {
            _grid[i - 1][x - 1] = false;
            r.set("/data/grid", _grid);
          }
        });
        rowe.append(cow);
      }

      String color;

      if (val == true) {
        color = "red";
      } else if (val == false) {
        color = "white";
      } else {
        color = "gray";
      }

      if (cow.style.backgroundColor != color) {
        cow.style.backgroundColor = color;
      }
    }
  }
}
