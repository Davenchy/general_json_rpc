import 'types/types.dart';

import 'package:event_object/event_object.dart';

class RpcController {
  bool _isBatching = false;
  final _batch = RpcBatch();

  /// [Event] object to handle send events
  final sendEvent = Event<RpcObject>(name: 'send_event');

  /// returns [true] if controller is in batch mode
  bool get isBatching => _isBatching;

  /// returns number of types in the batch list
  int get batchLength => _batch.rpcTypes.length;

  /// send request with [method] and [params]
  ///
  /// returns [Future] of type [T] as a response
  ///
  /// throws [RpcError] if response has error
  Future<T> request<T>(String method, [dynamic params]) async {
    final request = RpcRequest.create(method, params);
    sendRpc(request);
    return request.waitForResponse<T>();
  }

  /// send notification with [method] and [params]
  ///
  /// no response or error is expected
  void notify(String method, [dynamic data]) {
    final request = RpcRequest.notify(method, data);
    sendRpc(request);
  }

  /// send response of [requestId] and [data] as a returned value or as an result
  void response({required int requestId, dynamic data}) {
    final response = RpcResponse(id: requestId, result: data);
    sendRpc(response);
  }

  /// send error of [code] and [message] with optional [requestId] if error related to request also [data] if error has any
  void error({
    required int code,
    required String message,
    int? requestId,
    RpcMeta? data,
  }) {
    final error = RpcError(code: code, message: message, data: data);
    final response = RpcResponse(id: requestId, error: error);
    sendRpc(response);
  }

  /// send any [rpc] like [RpcRequest] or [RpcResponse]
  ///
  /// if batch mode is enabled [rpc] will added to the batch list instead of sending
  void sendRpc(RpcObjectType rpc) {
    if (_isBatching) {
      _batch.add(rpc);
    } else {
      sendRpcObject(rpc);
    }
  }

  /// start batch mode
  ///
  /// all [RpcRequest] and [RpcResponse] will be added to the batch list
  /// to be sent once
  void startBatch() {
    _isBatching = true;
    _batch.rpcTypes.clear();
  }

  /// send all [RpcRequest] and [RpcResponse] in the batch list then clear it and end batch mode
  ///
  /// [endBatch] is called under the hood
  void sendBatch() {
    sendBatchObject(_batch);
    endBatch();
  }

  /// only end the batch mode and clear the batch list without sending any thing
  ///
  /// ! Note: all elements in the batch list will be removed and never send
  void endBatch() {
    _batch.rpcTypes.clear();
    _isBatching = false;
  }

  /// send any rpc [object] examples [RpcRequest], [RpcResponse] and [RpcBatch]
  ///
  /// ! Note: this method is not affect by batch mode
  void sendRpcObject(RpcObject object) => sendEvent.fire(object);

  /// send [batch] object
  ///
  /// ! Note: this method is not affect by batch mode
  void sendBatchObject(RpcBatch batch) => sendRpcObject(batch);

  /// send [response] object
  ///
  /// ! Note: this method is not affect by batch mode
  void sendResponseObject(RpcResponse response) => sendRpcObject(response);

  /// send [request] object and wait for its response of type [T]
  ///
  /// also throws [RpcError] if response has error
  ///
  /// ! Note: this method is not affect by batch mode
  Future<T> sendRequestObject<T>(RpcRequest request) {
    sendRpcObject(request);
    return request.waitForResponse<T>();
  }
}
