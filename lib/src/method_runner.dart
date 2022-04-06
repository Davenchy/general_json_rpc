import 'dart:async';

import 'types/types.dart';

typedef JsonRpcCallback<R> = FutureOr<R?> Function(dynamic params);

class MethodRunner {
  /// Holds a [Map] of methods names and their callbacks to be called
  /// by calling the method by its name.
  ///
  /// Set a [prefix] string to be added to all methods names.
  ///
  /// This can be used to avoid name collisions.
  ///
  /// By default, the prefix is empty string.
  ///
  /// Example:
  /// ```dart
  ///
  /// final runner = MethodRunner();
  /// runner.register<int>('sum', (p) => p[0] + p[1]);
  ///
  /// final result = runner('sum, [1, 2]);
  /// print(result); // 3
  ///
  /// ```
  MethodRunner([this.prefix = '']);

  final Map<String, Function> _methods = {};

  /// Used to prefix all method names.
  ///
  /// Can be set on new instance of [MethodRunner]
  ///
  /// For example, if you have a method `foo` and you set `prefix` to `bar`
  /// then the method `bar.foo` will be called.
  final String prefix;

  /// Register a new [method] by its name and its [callback].
  ///
  /// If [prefix] is set, the method name will be prefixed with it.
  ///
  /// Example:
  ///
  /// [prefix] default value is **empty string**
  /// then method name will be `foo` and the method will be called by calling `foo`
  ///
  /// `register('foo', (_) {});` - `runner('foo')`
  ///
  /// if [prefix] is set to `scope` then method name will be `scope.foo`
  ///
  /// `register('foo', (_) {});` - `runner('scope.foo')`
  ///
  /// if method name is already registered, it will be overwritten.
  void register<R>(String method, JsonRpcCallback<R> callback) =>
      _methods[prefix + method] = callback;

  /// Removes a method by its name.
  void remove(String method) => _methods.remove(prefix + method);

  /// Checks if [method] is registered.
  bool has(String method) => _methods.containsKey(prefix + method);

  /// Clear all registered methods
  void clear() => _methods.clear();

  /// Calls or executes a [method] by its name.
  ///
  /// If [method] is not registered, it will throw [RpcError] of **code** [RpcError.kMethodNotFound]
  ///
  /// If [method] is registered, it will call the callback and return its result of type [R] as a [Future].
  ///
  /// If an error is thrown by the callback, it will be wrapped in [RpcError] of code [RpcError.kInternalError] and thrown.
  Future<R?> call<R>(String method, [dynamic params]) async {
    final callback = _methods[prefix + method];
    if (callback == null) {
      throw RpcError(
        code: RpcError.kMethodNotFound,
        message: 'Method not found',
        data: {
          'method': prefix + method,
          'registered_methods': _methods.keys.toList(),
        },
      );
    }

    try {
      final R? result = await callback(params);
      return result;
    } catch (err, stk) {
      throw RpcError(
        code: RpcError.kInternalError,
        message: 'Internal Error',
        data: {
          'method': prefix + method,
          'params': params,
          'error': err.toString(),
          'stacktrace': stk.toString(),
        },
      );
    }
  }
}
