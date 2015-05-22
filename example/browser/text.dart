import "dart:html";

import "package:dslink/browser.dart";

LinkProvider link;

const List<String> CSS_COLORS = const [
  "blue",
  "green",
  "red",
  "orange",
  "yellow",
  "magenta",
  "black",
  "white",
  "gold",
  "brown",
  "grey",
  "pink",
  "purple"
];

final String CSS_COLOR_ENUM = 'enum[${CSS_COLORS.join(",")}]';

BodyElement bodyElement = querySelector("#body");
ParagraphElement textElement = querySelector("#text");

main() async {
  link = new LinkProvider("http://127.0.0.1:8080/conn", "BrowserText-", defaultNodes: {
    "Page_Color": { // Page Background Color
      r"$name": "Page Color",
      r"$type": CSS_COLOR_ENUM,
      r"$writable": "write",
      "?value": "blue"
    },
    "Text": { // Text Message
      r"$name": "Text",
      r"$type": "string",
      r"$writable": "write",
      "?value": "Hello World"
    },
    "Text_Color": { // Text Color
      r"$name": "Text Color",
      r"$type": CSS_COLOR_ENUM,
      r"$writable": "write",
      "?value": "white"
    }
  }, loadNodes: true);

  await link.init();

  link.onValueChange("/Page_Color").listen((ValueUpdate update) async { // Wait for background color changes.
    bodyElement
      ..style.backgroundColor = update.value;
    await link.save();
  });

  link.onValueChange("/Text_Color").listen((ValueUpdate update) async { // Wait for text color changes.
    textElement
      ..style.color = update.value
      ..offsetHeight; // Trigger Re-flow
    await link.save();
  });

  link.onValueChange("/Text").listen((ValueUpdate update) async { // Wait for message changes.
    textElement
      ..text = update.value
      ..offsetHeight; // Trigger Re-flow
    await link.save();
  });

  // Re-sync Values to trigger subscribers.
  link.syncValue("/Page_Color");
  link.syncValue("/Text_Color");
  link.syncValue("/Text");

  link.connect();
}
