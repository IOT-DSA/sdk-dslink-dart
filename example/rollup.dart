import "package:dslink/api.dart";

void main() {
  var values = [1, 2, 3, 4].map((it) => Value.of(it)).toList();
  print(RollupType.SUM.create().combine(values));
}
