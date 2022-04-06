import 'dart:convert';

import 'error_object.dart';
import 'request_object.dart';
import 'response_object.dart';
import 'rpc_object.dart';

abstract class RpcObjectType extends RpcObject {
  final dynamic id;

  const RpcObjectType(this.id)
      : assert(id == null || id is String || id is int,
            'id must be null, int or string');

  /// Returns [RpcRequest] or [RpcResponse] from [meta]
  factory RpcObjectType.fromMeta(RpcMeta meta) {
    if (meta['jsonrpc'] == '2.0') {
      if (meta['method'] != null) {
        return RpcRequest.fromMeta(meta);
      } else {
        return RpcResponse.fromMeta(meta);
      }
    } else {
      throw RpcError(
        code: RpcError.kInvalidRequest,
        message: 'Invalid Request',
        data: {
          'error': 'Invalid jsonrpc version',
        },
      );
    }
  }

  @override
  List<int> encode({String postfix = '%SEP%'}) =>
      utf8.encode(jsonEncode(toMeta()) + postfix);

  /// Returns [RpcMeta] of the current [RpcObjectType]
  RpcMeta toMeta();

  /// This function is used to detect the type of [RpcObjectType] and ease handling it
  ///
  /// throws Exception if [rpcObject] extends type is unsupported
  ///
  /// [onBatch] is called if [rpcObject] is a [RpcBatch]
  ///
  /// [onRequest] is called if [rpcObject] is a [RpcRequest] and **is not** a notification
  ///
  /// [onNotification] is called if [rpcObject] is a [RpcRequest] and **is** a notification
  ///
  /// [onResponse] is called if [rpcObject] is a [RpcResponse]
  ///
  /// [onResult] is called if [rpcObject] is a [RpcResponse] and has a **result**
  ///
  /// [onError] is called if [rpcObject] is a [RpcResponse] and has an **error**
  static Future<RpcObject?> handle(
    RpcObjectType rpcObject, {
    RpcRequestHandler? onRequest,
    RpcResponseHandler? onResponse,
    NotificationHandler? onNotification,
    ResponseResultHandler? onResult,
    ResponseErrorHandler? onError,
  }) async {
    if (rpcObject is RpcResponse) {
      rpcObject.handle(onResult: onResult, onError: onError);
      return null;
    } else if (rpcObject is RpcRequest) {
      return await rpcObject.handle(
        onRequest: onRequest,
        onNotification: onNotification,
      );
    } else {
      throw Exception('UnSupported RpcObjectType type');
    }
  }
}
