import "dart:html";

import "package:dslink/browser.dart";
import "package:dslink/nodes.dart";

LinkProvider link;

final Map<String, String> TRANSITION_TIMES = {
  "Instant": "0s",
  "250ms": "0.25s",
  "500ms": "0.5s",
  "1s": "1s",
  "2s": "2s"
};

Map<String, dynamic> DEFAULT_NODES = {
  "User_Agent": {
    r"$name": "User Agent",
    r"$type": "string",
    "?value": window.navigator.userAgent
  },
  "Page_Color": { // Page Background Color
    r"$name": "Page Color",
    r"$type": "color",
    r"$writable": "write",
    "?value": "blue"
  },
  "Page_Gradient": {
    r"$name": "Page Gradient",
    r"$type": "gradient",
    r"$writable": "write",
    "?value": "none"
  },
  "Page_Color_Transition_Time": {
    r"$name": "Page Color Transition Time",
    r"$type": TRANSITION_ENUM,
    r"$writable": "write",
    "?value": "1s"
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
    "?value": "1s"
  },
  "Text_Color_Transition_Time": {
    r"$name": "Text Color Transition Time",
    r"$type": TRANSITION_ENUM,
    r"$writable": "write",
    "?value": "1s"
  },
  "Text_Color": { // Text Color
    r"$name": "Text Color",
    r"$type": "color",
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
    },
    "Down": {
      r"$type": "bool",
      "?value": false
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

BodyElement bodyElement = querySelector("#body");
ParagraphElement textElement = querySelector("#text");

AudioElement audio;

main() async {
  var brokerUrl = await BrowserUtils.fetchBrokerUrlFromPath("broker_url", "http://localhost:8080/conn");
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
  });

  await $.init();

  for (var key in DEFAULT_NODES.keys) {
    if (!link["/"].children.containsKey(key)) {
      $.addNode(key, DEFAULT_NODES[key]);
    }
  }

  $.onValueChange("/Page_Color").listen((ValueUpdate update) async { // Wait for background color changes.
    String color = update.value;
    try {
      color = "#${int.parse(update.value).toRadixString(16)}";
    } catch (e) {}
    bodyElement
      ..style.removeProperty("background")
      ..style.backgroundColor = color;
    await $.save();
  });

  $.onValueChange("/Text_Color").listen((ValueUpdate update) async { // Wait for text color changes.
    String color = update.value;
    try {
      color = "#${int.parse(update.value).toRadixString(16)}";
    } catch (e) {}
    textElement
      ..style.color = color
      ..offsetHeight; // Trigger Re-flow
    await $.save();
  });

  $.onValueChange("/Page_Gradient").listen((ValueUpdate update) async {
    if (update.value == "none") {
      return;
    }

    if (update.value == null) {
      $.val("/Page_Gradient", "none");
      return;
    }

    String x = update.value;
    bodyElement
      ..style.removeProperty("background-color")
      ..style.background = "linear-gradient(${x})";
  });

  $.onValueChange("/Text").listen((ValueUpdate update) async { // Wait for message changes.
    textElement
      ..text = update.value
      ..offsetHeight; // Trigger Re-flow
    await $.save();
  });

  $.onValueChange("/Text_Rotation").listen((ValueUpdate update) async {
    textElement
      ..style.transform = "rotate(${update.value}deg";
    await $.save();
  });

  $.onValueChange("/Page_Color_Transition_Time").listen((ValueUpdate update) async {
    var n = update.value;

    if (TRANSITION_TIMES.containsKey(n)) {
      n = TRANSITION_TIMES[n];
    }

    bodyElement
      ..style.transition = "background-color ${n}";

    await $.save();
  });

  $.onValueChange("/Text_Font").listen((ValueUpdate update) async {
    textElement
      ..style.fontFamily = '"' + update.value + '"'
      ..offsetHeight;
    await $.save();
  });

  $.onValueChange("/Text_Size").listen((ValueUpdate update) async {
    textElement
      ..style.fontSize = "${update.value}px"
      ..offsetHeight;
    await $.save();
  });

  $.onValueChange("/Page_Color_Transition_Time").listen((ValueUpdate update) async {
    var n = update.value;

    if (TRANSITION_TIMES.containsKey(n)) {
      n = TRANSITION_TIMES[n];
    }

    bodyElement
      ..style.transition = "background-color ${n}";

    await $.save();
  });

  $.onValueChange("/Text_Size_Transition_Time").listen((ValueUpdate update) async {
    var n = update.value;

    if (TRANSITION_TIMES.containsKey(n)) {
      n = TRANSITION_TIMES[n];
    }

    textElement
      ..style.transition = "font-size ${n}";

    await $.save();
  });

  $.onValueChange("/Text_Color_Transition_Time").listen((ValueUpdate update) async {
    var n = update.value;

    if (TRANSITION_TIMES.containsKey(n)) {
      n = TRANSITION_TIMES[n];
    }

    textElement
      ..style.transition = "color ${n}";

    await $.save();
  });

  bodyElement.onClick.listen((MouseEvent event) { // Update Click Information
    $.val("/Click/ID", (link["/Click/ID"].lastValueUpdate.value as int) + 1);
    $.val("/Click/X", event.page.x);
    $.val("/Click/Y", event.page.y);
  });

  textElement.onMouseEnter.listen((event) => $.val("/Text_Hovering", true));
  textElement.onMouseLeave.listen((event) => $.val("/Text_Hovering", false));

  bodyElement.onMouseMove.listen((MouseEvent event) {
    $.val("/Mouse/X", event.page.x);
    $.val("/Mouse/Y", event.page.y);
  });

  bodyElement.onMouseDown.listen((_) {
    $.val("/Mouse/Down", true);
  });

  bodyElement.onMouseUp.listen((_) {
    $.val("/Mouse/Down", false);
  });

  // Re-sync Values to trigger subscribers.
  [
    "/Page_Color_Transition_Time",
    "/Text_Color_Transition_Time",
    "/Text_Size_Transition_Time",
    "/Page_Color",
    "/Page_Gradient",
    "/Text_Color",
    "/Text",
    "/Text_Font",
    "/Text_Size"
  ].forEach($.syncValue);

  $.connect();
}

LinkProvider get $ => link;
