import "dart:html";

import "package:dslink/browser.dart";
import "package:dslink/nodes.dart";

LinkProvider link;

final List<String> CSS_COLORS = [
  "aqua",
  "fuchsia",
  "blue",
  "green",
  "red",
  "orange",
  "yellow",
  "maroon",
  "navy",
  "olive",
  "black",
  "white",
  "gold",
  "brown",
  "gray",
  "silver",
  "teal",
  "pink",
  "purple"
];

final Map<String, String> TRANSITION_TIMES = {
  "Instant": "0s",
  "Quarter of a Second": "0.25s",
  "Half a Second": "0.5s",
  "One Second": "1s",
  "Two Seconds": "2s"
};

Map<String, dynamic> DEFAULT_NODES = {
  "Page_Color": { // Page Background Color
    r"$name": "Page Color",
    r"$type": CSS_COLOR_ENUM,
    r"$writable": "write",
    "?value": "blue"
  },
  "Page_Color_Transition_Time": {
    r"$name": "Page Color Transition Time",
    r"$type": TRANSITION_ENUM,
    r"$writable": "write",
    "?value": "One Second"
  },
  "Text": { // Text Message
    r"$name": "Text",
    r"$type": "string",
    r"$writable": "write",
    "?value": "Hello World"
  },
  "Text_Size_Transition_Time": {
    r"$name": "Text Size Transition Time",
    r"$type": TRANSITION_ENUM,
    r"$writable": "write",
    "?value": "One Second"
  },
  "Text_Color_Transition_Time": {
    r"$name": "Text Color Transition Time",
    r"$type": TRANSITION_ENUM,
    r"$writable": "write",
    "?value": "One Second"
  },
  "Text_Color": { // Text Color
    r"$name": "Text Color",
    r"$type": CSS_COLOR_ENUM,
    r"$writable": "write",
    "?value": "white"
  },
  "Text_Font": {
    r"$name": "Text Font",
    r"$type": buildEnumType([
      "Arial",
      "Arial Black",
      "Comic Sans MS",
      "Courier New",
      "Georgia",
      "Impact",
      "Tahoma",
      "Lucida Console",
      "Times New Roman",
      "Trebuchet MS",
      "Verdana"
    ]),
    r"$writable": "write",
    "?value": "Arial"
  },
  "Text_Rotation": {
    r"$name": "Text Rotation",
    r"$type": "number",
    r"$writable": "write",
    "?value": 0.0
  },
  "Text_Size": {
    r"$name": "Text Size",
    r"$type": "number",
    r"$writable": "write",
    "?value": 72
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
};

final String TRANSITION_ENUM = buildEnumType(TRANSITION_TIMES.keys);
final String CSS_COLOR_ENUM = buildEnumType(CSS_COLORS);

BodyElement bodyElement = querySelector("#body");
ParagraphElement textElement = querySelector("#text");

AudioElement audio;

main() async {
  CSS_COLORS.sort();
  var brokerUrl = await BrowserUtils.fetchBrokerUrlFromPath("broker_url", "http://127.0.0.1:8080/conn");
  link = new LinkProvider(brokerUrl, "Browser-", defaultNodes: DEFAULT_NODES, profiles: {
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
  }, loadNodes: true);

  await link.init();

  for (var key in DEFAULT_NODES.keys) {
    if (!link["/"].children.containsKey(key)) {
      link.addNode(key, DEFAULT_NODES[key]);
    }
  }

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

  link.onValueChange("/Text_Rotation").listen((ValueUpdate update) async {
    textElement
      ..style.transform = "rotate(${update.value}deg";
    await link.save();
  });
  link.onValueChange("/Page_Color_Transition_Time").listen((ValueUpdate update) async {
    var n = update.value;

    if (TRANSITION_TIMES.containsKey(n)) {
      n = TRANSITION_TIMES[n];
    }

    bodyElement
      ..style.transition = "background-color ${n}";

    await link.save();
  });

  link.onValueChange("/Text_Font").listen((ValueUpdate update) async {
    textElement
      ..style.fontFamily = '"' + update.value + '"'
      ..offsetHeight;
    await link.save();
  });

  link.onValueChange("/Text_Size").listen((ValueUpdate update) async {
    textElement
      ..style.fontSize = "${update.value}px"
      ..offsetHeight;
    await link.save();
  });

  link.onValueChange("/Page_Color_Transition_Time").listen((ValueUpdate update) async {
    var n = update.value;

    if (TRANSITION_TIMES.containsKey(n)) {
      n = TRANSITION_TIMES[n];
    }

    bodyElement
      ..style.transition = "background-color ${n}";

    await link.save();
  });

  link.onValueChange("/Text_Size_Transition_Time").listen((ValueUpdate update) async {
    var n = update.value;

    if (TRANSITION_TIMES.containsKey(n)) {
      n = TRANSITION_TIMES[n];
    }

    textElement
      ..style.transition = "font-size ${n}";

    await link.save();
  });

  link.onValueChange("/Text_Color_Transition_Time").listen((ValueUpdate update) async {
    var n = update.value;

    if (TRANSITION_TIMES.containsKey(n)) {
      n = TRANSITION_TIMES[n];
    }

    textElement
      ..style.transition = "color ${n}";

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
  link.syncValue("/Page_Color_Transition_Time");
  link.syncValue("/Text_Color_Transition_Time");
  link.syncValue("/Text_Size_Transition_Time");
  link.syncValue("/Page_Color");
  link.syncValue("/Text_Color");
  link.syncValue("/Text");
  link.syncValue("/Text_Font");
  link.syncValue("/Text_Size");

  link.connect();
}
