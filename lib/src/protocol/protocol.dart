part of dslink.protocol;

class MessageException {
  final String message;
  
  MessageException(this.message);
  
  @override
  String toString() => message;
}