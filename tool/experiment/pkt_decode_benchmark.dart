import "package:dslink/common.dart";

final int warmupCount = 100000;
final int count = 50000000;

main() async {
  var listPacket = new DSRequestPacket();
  listPacket.method = DSPacketMethod.list;
  listPacket.path = "/";
  listPacket.rid = 920;
  listPacket.updateId = 911;
  listPacket.qos = 1;

  var reader = new DSPacketReader();
  var writer = new DSPacketWriter();

  var watch = new Stopwatch();
  var bytes = listPacket.write(writer);

  for (var i = 1; i <= warmupCount; i++) {
    var pkt = reader.read(bytes);
  }

  watch.start();
  for (var i = 1; i <= count; i++) {
    var pkt = reader.read(bytes);
  }
  watch.stop();

  print(
    "Took ${watch.elapsedMicroseconds} microseconds"
      " (${watch.elapsedMilliseconds}ms) to decode"
      " a packet ${count} times."
  );
}
