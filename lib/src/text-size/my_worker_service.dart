import 'dart:async';

import 'package:squadron/squadron.dart';

import 'size_service.dart';

// this abstract class represents the functionality you want to support in your service
abstract class MyWorkerService {
  FutureOr doSomethingWithTexts(List texts);

  // this constant is used to identify the method to call when communicating with isolates / web workers
  static const doSomethingWithTextsCommand = 1;
}

// this class is the actual implementation of the service defined above
class MyWorkerServiceImpl implements MyWorkerService, WorkerService {
  MyWorkerServiceImpl(this._sizeService);

  // in Workers, the _sizeService will be set to a SizeClient to communicate with the TextSizeServer in the main Isolate
  final SizeService _sizeService;

  @override
  Future doSomethingWithTexts(List texts) async {
    for (var text in texts) {
      final size = await _sizeService.measure(text);
      Squadron.info('$text --> ${size['w']}x${size['h']}');
    }
  }

  // this map creates the correspondance between the service constants from MyWorkerService
  // and the method implementations in MyWorkerServiceImpl
  @override
  late final Map<int, CommandHandler> operations = {
    MyWorkerService.doSomethingWithTextsCommand: (WorkerRequest r) =>
        doSomethingWithTexts(r.args[0])
  };
}
