import "package:dslink/api.dart";

void main() {
  var values = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15].map(wrapValue).toList();
  print(RollupType.SUM.create().combine(values));
}

Value wrapValue(input) => Value.of(input);