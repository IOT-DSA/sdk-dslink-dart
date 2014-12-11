part of dslink;

class DSAExposed {
  const DSAExposed();  
}

class DSAMessage {
  final String subscription;
  final List<Map<String, dynamic>> requests;
  final List<Map<String, dynamic>> responses;
  
  DSAMessage._({this.subscription, this.requests, this.responses});
  
  DSAMessage.request({String subscription}) : this._(subscription: subscription, requests: []);
  DSAMessage.response({String subscription}) : this._(subscription: subscription, responses: []);
  
  bool get isRequest => requests != null;
  bool get isResponse => responses != null;
  bool get hasSubscription => subscription != null;
}

class MessageException {
  final String message;
  
  MessageException(this.message);
}