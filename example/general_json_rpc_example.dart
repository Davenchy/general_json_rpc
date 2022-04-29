/*

  In this example you will see how to use this package on tcp server and client sides

  server() method is the server side
  client() method is the client side

  on the server method we will define 3 rpc methods [sum, print, quit]

  the `sum` method will take a list of numbers and returns their sum
  the `print` method will get a `message` parameter and prints its content
  the `quit` method with end the application by executing `exit(0);`

  on the client side we will call the 3 methods and wait for results

*/

import 'dart:io';

import 'package:general_json_rpc/general_json_rpc.dart';

void main() {
  server();
  client();
}

void server() async {
  final server = await ServerSocket.bind(InternetAddress.anyIPv4, 8081);
  print('[server] Server is running on port 8081');

  // create MethodRunner to define the rpc methods
  final runner = MethodRunner();

  // now lets define the 3 methods
  runner.register<int>('sum', (numbers) => numbers.reduce((a, b) => a + b));
  runner.register<void>('print', (p) => print(p['message']));
  runner.register<void>('quit', (_) => exit(0));

  // now lets listen for new clients
  await for (final Socket client in server) {
    print('[server] new client');
    client.listen(
      (bytes) async {
        // converts bytes into [RpcObject]
        final rpcObject = RpcObject.decode(bytes);

        // now lets handle all cases
        final response = await RpcObject.auto(rpcObject, methodRunner: runner);

        // now lets send the response to the client if it is not null
        // before send we must convert it to bytes using the `encode()` method
        if (response != null) client.add(response.encode());
      },
    );
  }
}

void client() async {
  print('[client] connecting...');
  final client = await Socket.connect(InternetAddress.loopbackIPv4, 8081);
  print('[client] connected!');

  // lets create controller to help send requests and responses
  final controller = RpcController();

  // lets listen for messages
  client.listen(
    (bytes) async {
      // lets use our controller to send requests and responses
      controller.sendEvent.addListener(
        // ! encode [rpcMessage] before send
        (rpcMessage) => client.add(rpcMessage.encode()),
      );

      // convert bytes into [RpcObject]
      final rpcObject = RpcObject.decode(bytes);

      // now lets handle the rpcObject
      RpcObject.auto(rpcObject, controller: controller);
    },
  );

  // now lets first request the `sum` method
  // we will pass 3 numbers 1, 2, 3 in a list
  // the sum will return as Future<int>
  // we can handle errors by listening for [RpcError]
  controller.request<int>('sum', [1, 2, 3]).then((result) {
    print('[client] sum result: $result');
  }).onError<RpcError>((error, _) {
    print('[client] error: ${error.message}');
  });

  // ============================= //
  // now lets call the `print` method without expecting a response
  controller.notify(
    'print',
    {
      'message': 'A message to be printed on the server side by the client',
    },
  );

  // ============================= //
  // now lets shutdown the server by calling the `quit` method after 5 seconds
  // we expect no returned value
  // so we will send a rpc notification
  await Future.delayed(
    const Duration(seconds: 5),
    () => controller.notify('quit'),
  );
}
