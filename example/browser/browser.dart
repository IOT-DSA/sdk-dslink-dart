import "dart:html";

import "package:dslink/browser.dart";
import "package:dslink/nodes.dart";

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

AudioElement audio;

main() async {
  var brokerUrl = await BrowserUtils.fetchBrokerUrlFromPath("broker_url", "http://127.0.0.1:8080/conn");
  link = new LinkProvider(brokerUrl, "Browser-", defaultNodes: {
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
    },
    "Click": {
      "ID": {
        r"$type": "number",
        "?value": 0
      },
      "X": {
        r"$type": "number",
        "?value": 0.0
      },
      "Y": {
        r"$type": "number",
        "?value": 0.0
      }
    },
    "Text_Hovering": { // If the user is currently hovering over the text.
      r"$name": "Hovering over Text",
      r"$type": "bool",
      "?value": false
    },
    "Mouse": { // Mouse-related stuff.
      "X": { // Mouse X position.
        r"$type": "number",
        "?value": 0.0
      },
      "Y": { // Mouse y position.
        r"$type": "number",
        "?value": 0.0
      }
    },
    "Play_Sound": { // An action to play a sound.
      r"$name": "Play Sound",
      r"$is": "playSound",
      r"$invokable": "write",
      r"$params": [
        {
          "name": "url",
          "type": "string"
        }
      ]
    },
    "Stop_Sound": {
      r"$name": "Stop Sound",
      r"$is": "stopSound",
      r"$invokable": "write"
    }
  }, profiles: {
    "playSound": (String path) =>
      new SimpleActionNode(path, (Map<String, dynamic> params) {
        if (audio != null) {
          audio.pause();
          audio = null;
        }

        audio = new AudioElement();
        audio.src = params["url"];
        audio.play();
      }),
    "stopSound": (String path) =>
      new SimpleActionNode(path, (Map<String, dynamic> params) {
        if (audio != null) {
          audio.pause();
          audio = null;
        }
      })
  });

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

  bodyElement.onClick.listen((MouseEvent event) { // Update Click Information
    link.updateValue("/Click/ID", (link["/Click/ID"].lastValueUpdate.value as int) + 1);
    link.updateValue("/Click/X", event.page.x);
    link.updateValue("/Click/Y", event.page.y);
  });

  textElement.onMouseEnter.listen((event) => link.updateValue("/Text_Hovering", true));
  textElement.onMouseLeave.listen((event) => link.updateValue("/Text_Hovering", false));

  bodyElement.onMouseMove.listen((MouseEvent event) {
    link.updateValue("/Mouse/X", event.page.x);
    link.updateValue("/Mouse/Y", event.page.y);
  });

  // Re-sync Values to trigger subscribers.
  link.syncValue("/Page_Color");
  link.syncValue("/Text_Color");
  link.syncValue("/Text");

  link.connect();
}
