import 'dart:math';

import '../rpc_response_manager.dart';
import 'error_object.dart';
import 'rpc_object.dart';
import 'rpc_object_type.dart';
import 'response_object.dart';

class RpcRequest extends RpcObjectType {
  final String method;
  final dynamic params;

  const RpcRequest({required this.method, dynamic id, this.params})
      : assert(
            params == null || params is List || params is Map<String, dynamic>,
            'params must be null, list or map'),
        super(id);

  /// Creates a new [RpcRequest] with a random [id]
  RpcRequest.create(this.method, [this.params]) : super(generateId());

  /// Creates a new [RpcRequest] as a notification request
  RpcRequest.notify(this.method, [this.params]) : super(null);

  /// Creates a new [RpcRequest] from [meta]
  factory RpcRequest.fromMeta(RpcMeta meta) => RpcRequest(
        id: meta['id'],
        method: meta['method'],
        params: meta['params'],
      );

  /// Returns a new generated integer in range [0, 1 << 32]
  static int generateId() => Random.secure().nextInt(1 << 32);

  /// Is this request a notification request
  bool get isNotification => id == null;

  /// Is the [id] of type [String]
  bool get isIdString => id is String;

  /// Is the [id] of type [int]
  bool get isIdInt => id is int;

  /// Returns [true] if this request has an [params]
  bool get hasParams => params != null;

  /// Returns **true** if [params] is a [List]
  bool get isParamsList => params is List;

  /// Returns **true** if [params] is a [Map]
  bool get isParamsMap => params is Map<String, dynamic>;

  @override
  RpcMeta toMeta() => {
        'jsonrpc': '2.0',
        'method': method,
        'params': params,
        'id': id,
      };

  /// Returns a [RpcResponse] instance with [result] or [error] with the current request [id]
  ///
  /// if both [result] and [error] are set and error will be thrown
  RpcResponse createResponse(dynamic result, [RpcError? error]) {
    assert(result == null || error == null, 'only result or error can be set');
    return RpcResponse(id: id, result: result, error: error);
  }

  /// A shortcut to request a [method] with [params] and wait for its result of type [T]
  ///
  /// By default [responseManager] is null and will be set to [RpcResponseManager.global]
  Future<T> waitForResponse<T>([RpcResponseManager? responseManager]) =>
      (responseManager ?? RpcResponseManager.global).waitForResponse<T>(this);

  /// This function is used to detect if this request is a notification or not
  ///
  /// Returns [Future] of [RpcResponse] if their is a response
  ///
  /// [onRequest] is called if this request **is not** a notification
  ///
  /// [onNotification] is called if this request **is** a notification
  Future<RpcResponse?> handle({
    RpcRequestHandler? onRequest,
    NotificationHandler? onNotification,
  }) async {
    if (isNotification) {
      onNotification?.call(this);
      return null;
    } else {
      return onRequest?.call(this);
    }
  }

  dynamic operator [](dynamic key) => params?[key];
  void operator []=(dynamic key, dynamic value) => params?[key] = value;

  @override
  String toString() =>
      'JsonRpcRequest(id: $id, method: $method, isNotification: $isNotification, params: $params)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RpcRequest &&
        other.method == method &&
        other.params == params;
  }

  @override
  int get hashCode => method.hashCode ^ params.hashCode;
}
