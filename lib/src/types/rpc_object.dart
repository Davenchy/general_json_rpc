import 'dart:async';
import 'dart:convert';

import '../method_runner.dart';
import '../extensions.dart';
import '../rpc_controller.dart';
import 'batch_object.dart';
import 'error_object.dart';
import 'request_object.dart';
import 'response_object.dart';
import 'rpc_object_type.dart';

import 'package:event_object/event_object.dart';

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

  /// this event used to handle incoming responses
  static final responseEvent = Event<RpcResponse>(
    name: 'response_event',
    historyLimit: 0,
  );

  /// creates [RpcObject] from [Map] or [List] of [Map]
  ///
  /// [Map] is used to create [RpcRequest] or [RpcResponse]
  ///
  /// [List] is used to create [RpcBatch] which a list of [RpcRequest] and [RpcResponse]
  ///
  /// throws [Exception] if [rpcObject] is not a [Map] or [List]
  ///
  /// throws [RpcError] with code [RpcError.kInvalidRequest] if failed to create object
  factory RpcObject.fromMeta(dynamic meta) {
    assert(meta is Map || meta is List, 'meta must be Map or List');

    if (meta is Map && meta['jsonrpc'] == '2.0') {
      if (meta.containsKey('method')) {
        return RpcRequest.fromMeta(meta.cast<String, dynamic>());
      } else {
        return RpcResponse.fromMeta(meta.cast<String, dynamic>());
      }
    } else if (meta is List) {
      return RpcBatch.fromMeta(meta.cast<Map<String, dynamic>>());
    } else {
      throw RpcError(
        code: RpcError.kInvalidRequest,
        message: 'Invalid Request',
        data: {
          'error': 'Invalid jsonrpc',
          'data': meta,
        },
      );
    }
  }

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
        final object = RpcObject.fromMeta(meta);
        if (object is RpcBatch) {
          batch.addAll(object.rpcTypes);
        } else {
          batch.add(object as RpcObjectType);
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

  /// Will automatically handle [RpcObject] and return [RpcResponse] if exists
  ///
  /// it handles requests using [methodRunner] and auto send response using [controller]
  static Future<RpcObject?> auto(
    RpcObject rpcObject, {
    MethodRunner? methodRunner,
    RpcController? controller,
  }) async {
    final response = await handle(
      rpcObject,
      onRequestAll: methodRunner?.executeRequest,
      onResponse: (response) => responseEvent.fire(response),
    );
    if (response != null && controller != null) {
      controller.sendRpcObject(response);
    }
    return response;
  }

  /// register request and wait for its response
  ///
  /// if response is error throws [RpcError]
  ///
  /// else returns result of type [T] if no result returns [Null]
  static Future<T> registerRequest<T>(RpcRequest request) async {
    final completer = Completer<T>();
    final killer = responseEvent.addListener((response) {
      if (response.id == request.id) {
        if (response.hasError) {
          completer.completeError(response.error!);
        } else {
          completer.complete(response.result);
        }
      }
    });
    return completer.future.whenComplete(killer);
  }
}
