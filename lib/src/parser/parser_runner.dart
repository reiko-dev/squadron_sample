import 'package:squadron/squadron.dart';

import 'parser_service.dart';
import 'signal_value.dart';

final _sw = Stopwatch()..start();

void _log(dynamic message) => Squadron.info(message);

const void Function(Object? object)? log = _log;

class ParseArguments {
  ParseArguments(this.parser, this.lines, this.nbOfChunks, this.token);

  final ParserService parser;
  final List<String> lines;
  final int nbOfChunks;
  final CancellationToken token;
}

const _oneSec = Duration(seconds: 1);

Future<List> parse(ParseArguments args) async {
  final parser = args.parser;
  final lines = args.lines;
  final nbOfChunks = args.nbOfChunks;
  final token = args.token;

  if (token.cancelled) return [];
  await Future.delayed(_oneSec);
  if (token.cancelled) return [];

  final pool = (parser is WorkerPool) ? (parser as WorkerPool) : null;
  final linesPerBatch = lines.length ~/ nbOfChunks;

  _sw.reset();

  if (pool != null) {
    final concurrency = pool.concurrencySettings;
    log?.call(
        'START: lines = ${lines.length} / nb of chunks = $nbOfChunks / pool: ${concurrency.minWorkers}-${concurrency.maxWorkers} workers');
  } else {
    log?.call(
        'START: lines = ${lines.length} / nb of chunks = $nbOfChunks / no pool');
  }

  final futures = <Future<List>>[];

  // split & start parsing
  while (lines.length > linesPerBatch) {
    // take chunk
    final chunk = lines.sublist(0, linesPerBatch);
    lines.removeRange(0, linesPerBatch);
    // adjust chunk to next timestamp
    while (lines.isNotEmpty && !lines[0].startsWith('#')) {
      chunk.add(lines.removeAt(0));
    }
    // parse chunk
    log?.call('    batch #${futures.length + 1} = ${chunk.length} lines');
    futures.add(parser.parse(chunk, token));
  }
  // parse last chunk
  if (lines.isNotEmpty) {
    log?.call('    batch #${futures.length + 1} = ${lines.length} lines');
    futures.add(parser.parse(lines, token));
  }

  log?.call('STARTED ${futures.length} FUTURES, WAITING FOR RESULTS...');

  final chunks = await Future.wait(futures);
  if (token.cancelled) return [];

  log?.call('MERGING AND CONVERTING RESULTS');
  final signalValues = <SignalValue>[];
  for (var i = 0; i < chunks.length; i++) {
    signalValues.addAll(chunks[i].map((data) => SignalValue.load(data)));
  }

  final elapsed = _sw.elapsedMilliseconds;

  log?.call(
      'DONE PARSING: total items = ${signalValues.length} in ${_sw.elapsed}, ${signalValues.length / elapsed} item/ms');
  log?.call('    first = ${signalValues.first}');
  log?.call('    last = ${signalValues.last}');

  if (pool != null) {
    log?.call('Pool stats');
    final stats = pool.fullStats.toList();
    for (var i = 0; i < stats.length; i++) {
      final stat = stats[i];
      log?.call(
          '    #$i ${stat.status} current = ${stat.workload} / total/max/errors = ${stat.totalWorkload}/${stat.maxWorkload}/${stat.totalErrors}');
    }
  }

  // just to see ticks start again
  await Future.delayed(_oneSec);

  return signalValues;
}
