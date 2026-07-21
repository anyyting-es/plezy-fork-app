import 'package:flutter/material.dart';

class WatchBusyOverlays extends StatelessWidget {
  final bool loading;
  final String? error;
  final bool rdResolving;
  final String rdStatusMessage;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const WatchBusyOverlays({
    super.key,
    required this.loading,
    this.error,
    required this.rdResolving,
    required this.rdStatusMessage,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Container(
        color: Colors.black87,
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
                TextButton(onPressed: onBack, child: const Text('Volver', style: TextStyle(color: Colors.white70))),
              ],
            ),
          ),
        ),
      );
    }

    if (rdResolving) {
      return Container(
        color: Colors.black87,
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.greenAccent),
                const SizedBox(height: 24),
                const Text('Real-Debrid', style: TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(rdStatusMessage, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      );
    }

    if (loading) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return const SizedBox.shrink();
  }
}
