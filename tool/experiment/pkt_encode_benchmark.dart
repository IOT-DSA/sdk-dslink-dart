import "package:dslink/common.dart";

final int warmupCount = 100000;
final int count = 1000000;

main() async {
  var listPacket = new DSRequestPacket();
  listPacket.method = DSPacketMethod.list;
  listPacket.path = "/";
  listPacket.rid = 920;
  listPacket.updateId = 911;
  listPacket.qos = 1;

  var writer = new DSPacketWriter();

  var watch = new Stopwatch();

  for (var i = 1; i <= warmupCount; i++) {
    var bytes = listPacket.write(writer);
  }

  watch.start();
  for (var i = 1; i <= count; i++) {
    var bytes = listPacket.write(writer);
  }
  watch.stop();

  print(
    "Took ${watch.elapsedMicroseconds} microseconds"
      " (${watch.elapsedMilliseconds}ms) to encode"
      " a packet ${count} times."
  );
}
