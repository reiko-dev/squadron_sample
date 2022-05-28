import 'package:squadron/squadron.dart';

import 'dft_service.dart';
import 'dft_worker_activator.dart'
    if (dart.library.js) 'package:squadron_sample/src/dft/browser/dft_worker_activator.dart'
    if (dart.library.html) 'package:squadron_sample/src/dft/browser/dft_worker_activator.dart'
    if (dart.library.io) 'package:squadron_sample/src/dft/vm/dft_worker_activator.dart';

class DftWorkerPool extends WorkerPool<DftWorker> implements DftService {
  DftWorkerPool(ConcurrencySettings concurrencySettings)
      : super(createWorker, concurrencySettings: concurrencySettings);

  @override
  Stream<List> computeDFT(List x, CancellationToken? token) =>
      stream((w) => w.computeDFT(x, token));
}

class DftWorker extends Worker implements DftService {
  DftWorker(dynamic entryPoint, {List args = const []})
      : super(entryPoint, args: args);

  @override
  Stream<List> computeDFT(List x, CancellationToken? token) =>
      stream(DftService.getNDigitsCommand, args: [x], token: token);
}
