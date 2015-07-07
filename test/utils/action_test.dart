library dslink.test.utils.actions;

import "package:dslink/utils.dart";
import "package:test/test.dart";

main() => group("Actions", actionTests);

actionTests() {
  test("buildActionIO works", () {
    expect(buildActionIO({
      "name": "string",
      "input": "string"
    }), equals([
      {
        "name": "name",
        "type": "string"
      },
      {
        "name": "input",
        "type": "string"
      }
    ]));
  });

  test("buildEnumType works", () {
    expect(buildEnumType([
      "A",
      "B",
      "C",
      "D"
    ]), equals("enum[A,B,C,D]"));
  });
}
