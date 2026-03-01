import 'dart:async';
import 'package:flutter/foundation.dart';

enum OperationStatus {
  idle,
  running,
  completed,
  error,
}

class OperationProgress {
  final int done;
  final int total;

  OperationProgress(this.done, this.total);

  double get percent => total == 0 ? 0 : done / total;
}

class OperationController {
  final ValueNotifier<OperationStatus> status =
      ValueNotifier(OperationStatus.idle);

  final StreamController<OperationProgress>
      _progressController =
      StreamController.broadcast();

  Stream<OperationProgress> get progressStream =>
      _progressController.stream;

  String? resultMessage;
  String? errorMessage;

  void start() {
    status.value = OperationStatus.running;
  }

  void updateProgress(int done, int total) {
    _progressController.add(
      OperationProgress(done, total),
    );
  }

  void complete({String? message}) {
    resultMessage = message;
    status.value = OperationStatus.completed;
  }

  void fail(String? error) {
    error = error ?? "An unknown error occurred.";
    status.value = OperationStatus.error;
  }

  void reset() {
    resultMessage = null;
    errorMessage = null;
    status.value = OperationStatus.idle;
  }

  void dispose() {
    _progressController.close();
  }
}