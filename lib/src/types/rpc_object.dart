import 'dart:convert';

import '../method_runner.dart';
import '../extensions.dart';
import '../rpc_response_manager.dart';
import 'batch_object.dart';
import 'error_object.dart';
import 'request_object.dart';
import 'response_object.dart';
import 'rpc_object_type.dart';

typedef RpcMeta = Map<String, dynamic>;

// define types for handling callbacks
typedef RpcBatchHandler = Future<RpcBatch?> Function(RpcBatch batch);
typedef RpcResponseHandler = void Function(RpcResponse response);
typedef RpcRequestHandler = Future<RpcResponse?> Function(RpcRequest request);
typedef NotificationHandler = void Function(RpcRequest notification);
typedef ResponseResultHandler = void Function(dynamic id, dynamic result);
typedef ResponseErrorHandler = void Function(dynamic id, RpcError error);

abstract class RpcObject {
  const RpcObject();

  /// Returns [RpcBatch] if decoded [bytes] is a [List]
  ///
  /// Returns [RpcResponse] or [RpcResponse] if decoded [bytes] is a [Map]
  ///
  /// Throws [RpcError] with code [RpcError.kInvalidRequest] if decoded [bytes] is not a [Map] or [List]
  factory RpcObject.decode(List<int> bytes, {separator = '%SEP%'}) {
    final batch = RpcBatch();

    utf8.decode(bytes).split(separator).where((str) => str.isNotEmpty).forEach(
      (str) {
        final meta = jsonDecode(str);

        if (meta is Map) {
          batch.add(RpcObjectType.fromMeta(meta.cast<String, dynamic>()));
        } else if (meta is List) {
          batch.addAll(meta
              .cast<RpcMeta>()
              .map((meta) => RpcObjectType.fromMeta(meta))
              .toList());
        } else {
          throw RpcError(
            code: RpcError.kInvalidRequest,
            message: 'Invalid Request',
            data: {
              'error':
                  'Expected a List or Map but got ${meta.runtimeType.toString()}',
            },
          );
        }
      },
    );

    if (batch.length == 1) {
      return batch.rpcTypes.first;
    } else {
      return batch;
    }
  }

  /// Encodes [RpcObject] to **bytes** list
  List<int> encode({String postfix = '\$sep\$'});

  /// This function is used to detect the type of [RpcObject] and ease handling it
  ///
  /// throws Exception if [rpcObject] extends type is unsupported
  ///
  /// [onBatch] is called if [rpcObject] is a [RpcBatch]
  ///
  /// [onRequestAll] is called if [rpcObject] is a [RpcRequest],
  /// If [onRequestAll] is set then it **overwrite** [onRequest] and [onNotification]
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
    RpcObject rpcObject, {
    RpcBatchHandler? onBatch,
    RpcRequestHandler? onRequestAll,
    RpcRequestHandler? onRequest,
    NotificationHandler? onNotification,
    RpcResponseHandler? onResponse,
    ResponseResultHandler? onResult,
    ResponseErrorHandler? onError,
  }) async {
    if (rpcObject is RpcBatch) {
      if (rpcObject.isEmpty) return null;
      final resultBatch = await rpcObject.handle(
        onRequestAll: onRequestAll,
        onRequest: onRequest,
        onNotification: onNotification,
        onResponse: onResponse,
        onResult: onResult,
        onError: onError,
      );
      return resultBatch.isEmpty ? null : resultBatch;
    } else if (rpcObject is RpcResponse) {
      rpcObject.handle(onResult: onResult, onError: onError);
      onResponse?.call(rpcObject);
      return null;
    } else if (rpcObject is RpcRequest) {
      return onRequestAll != null
          ? onRequestAll.call(rpcObject)
          : rpcObject.handle(
              onRequest: onRequest,
              onNotification: onNotification,
            );
    } else {
      throw Exception('UnSupported RpcObject type');
    }
  }

  /// Will automatically handle [RpcObject] and return [RpcResponse] if exist
  ///
  /// It uses [RpcResponseManager.global] by default to handle responses
  static Future<RpcObject?> auto(
    RpcObject rpcObject, {
    MethodRunner? methodRunner,
    RpcResponseManager? responseManager,
  }) =>
      handle(
        rpcObject,
        onRequestAll: methodRunner?.executeRequest,
        onResponse:
            (responseManager ?? RpcResponseManager.global).handleResponse,
      );
}
