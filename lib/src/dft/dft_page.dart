import 'dart:async';

import 'package:flutter/material.dart';
import 'package:squadron/squadron.dart';
import 'package:squadron_sample/src/dft/dft_worker_pool.dart';
import 'package:squadron_sample/src/dft/drawings.dart';

class DftPage extends StatefulWidget {
  const DftPage({Key? key, this.tabBar}) : super(key: key);

  final _count = 5000;

  final TabBar? tabBar;

  @override
  State<DftPage> createState() => _DftPageState();
}

class _DftPageState extends State<DftPage> {
  _DftPageState();

  List<List<dynamic>> _digits = [];
  final computedNumbers = ValueNotifier<int>(0);
  bool _cancel = false;
  CancellationToken? _cancelToken;
  bool isComputing = false;

  void _startCompute() {
    Squadron.info('_startCompute called from ${StackTrace.current}');
    _cancel = false;
    _cancelToken = CancellationToken('Task was cancelled by the user');
    _digits = [];
    computedNumbers.value = 0;
    setState(() {
      isComputing = true;
    });
  }

  void _stopCompute() {
    setState(() {
      isComputing = false;
    });
  }

  Future _loadDFT(int batch, Stream<List> digits) async {
    try {
      await for (var d in digits) {
        computedNumbers.value++;

        _digits.add(d);
      }
      Squadron.info('[_loadNDigits] computation for completed successfully');
    } on CancelledException catch (e) {
      Squadron.info('[_loadNDigits] computation cancelled: ${e.message}');
    } on WorkerException catch (e) {
      Squadron.info('[_loadNDigits] computation failed: ${e.message}');
    } catch (e) {
      Squadron.info('[_loadNDigits] computation failed: $e');
    }
  }

  void _loadDftWorkerPool() async {
    _startCompute();

    DftWorkerPool? dftWorkerPool;
    try {
      dftWorkerPool = DftWorkerPool(
        const ConcurrencySettings(minWorkers: 1, maxWorkers: 1, maxParallel: 2),
      );
      await dftWorkerPool.start();

      var sw = Stopwatch()..start();
      if (_cancel) {
        Squadron.info('[_loadDftWorkerPool] computation has been cancelled');
      } else {
        try {
          Squadron.info('[_loadDftWorkerPool] computation started');
          await _loadDFT(
            widget._count,
            dftWorkerPool.computeDFT(getDrawingAsDoubleList(), _cancelToken),
          );
          Squadron.info('[_loadDftWorkerPool] computation completed');
        } on CancelledException {
          _cancel = true;
          Squadron.info(
              '[_loadDftWorkerPool] computation has been cancelled by user');
        }
      }

      sw.stop();
      Squadron.info('[_loadDftWorkerPool] elapsed = ${sw.elapsed}');
    } catch (e, st) {
      Squadron.info('[_loadDftWorkerPool] ERROR = $e');
      Squadron.info('[_loadDftWorkerPool] TRACE = $st');
    } finally {
      dftWorkerPool?.stop();
      if (!_cancel) {
        await Future.delayed(Duration.zero);
      }
      _stopCompute();
    }
  }

  void _cancelTasks() {
    _cancel = true;
    _cancelToken?.cancel();
  }

  @override
  void dispose() {
    computedNumbers.dispose();
    super.dispose();
  }

  String get _pi {
    String r = "";

    for (var d in _digits) {
      r += "(${d[0].toStringAsFixed(1)},${d[1].toStringAsFixed(1)}),";
    }
    return r;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('SQUADRON SAMPLE - DFT'),
          bottom: widget.tabBar,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'First ${widget._count} hexadecimal digits of Pi:',
              ),
              ValueListenableBuilder<int>(
                valueListenable: computedNumbers,
                builder: (context, value, _) {
                  if (value == 0) return const SizedBox.shrink();

                  return Text("Computed numbers: $value");
                },
              ),
              if (isComputing)
                const Center(
                  child: CircularProgressIndicator(),
                ),
              Expanded(child: SingleChildScrollView(child: Text(_pi))),
            ],
          ),
        ),
        floatingActionButton: isComputing
            ? FloatingActionButton(
                onPressed: _cancelTasks,
                tooltip: 'Cancel',
                child: const Text('Cancel', textAlign: TextAlign.center),
              )
            : FloatingActionButton(
                onPressed: _loadDftWorkerPool,
                tooltip: 'Pool',
                child: const Text('Pool', textAlign: TextAlign.center),
              ));
  }
}
