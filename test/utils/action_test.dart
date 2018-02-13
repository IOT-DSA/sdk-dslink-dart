library dslink.test.utils.actions;

import "package:dslink/utils.dart";
import "package:test/test.dart";
import "package:dslink/historian.dart";

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

  test("test get_history", () {
    expect(parseInterval('1D'), equals(86400000));
    MaxRollup rlp = new MaxRollup();
    rlp.add(43);
    rlp.add("101");
    expect(rlp.value, equals(101));
    MinRollup mrlp = new MinRollup();
    mrlp.add(43);
    mrlp.add("101");
    expect(mrlp.value, equals(43));
  });
}
