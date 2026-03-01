import 'package:flutter/material.dart';

import 'operation_controller.dart';

void showOperationDialog({
  required BuildContext context,
  required String title,
  required String description,
  required String confirmText,
  required Future<void> Function(OperationController op) onConfirm,
  bool autoCloseOnSuccess = false,
  
}) {
  final op = OperationController();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _OperationDialogContent(
            title: title,
            description: description,
            confirmText: confirmText,
            op: op,
            onConfirm: () => onConfirm(op),
            autoCloseOnSuccess: autoCloseOnSuccess,
          ),
        ),
      );
    },
  );
}

class _OperationDialogContent extends StatelessWidget {
  final String title;
  final String description;
  final String confirmText;
  final OperationController op;
  final Future<void> Function() onConfirm;
  final bool autoCloseOnSuccess;

  const _OperationDialogContent({
    required this.title,
    required this.description,
    required this.confirmText,
    required this.op,
    required this.onConfirm,
    required this.autoCloseOnSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: op.status,
      builder: (_, status, __) {
        if (status == OperationStatus.idle) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(description),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  TextButton(
                    onPressed: () async {
                      op.start();
                      await onConfirm();
                    },
                    child: Text(confirmText),
                  ),
                ],
              ),
            ],
          );
        }

        if (status == OperationStatus.running) {
          return StreamBuilder<OperationProgress>(
            stream: op.progressStream,
            builder: (_, snapshot) {
              final progress = snapshot.data;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Processing..."),
                  const SizedBox(height: 20),
                  LinearProgressIndicator(value: progress?.percent),
                  const SizedBox(height: 10),
                  if (progress != null)
                    Text("${progress.done}/${progress.total}"),
                ],
              );
            },
          );
        }

        if (status == OperationStatus.completed) {
          if (autoCloseOnSuccess) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pop(context);
              op.dispose();
            });

            return const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 50),
              const SizedBox(height: 10),
              Text(op.resultMessage ?? "Completed"),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  op.dispose();
                },
                child: const Text("OK"),
              ),
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 50),
            const SizedBox(height: 10),
            Text(op.errorMessage ?? "Operation failed"),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                op.dispose();
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }
}
