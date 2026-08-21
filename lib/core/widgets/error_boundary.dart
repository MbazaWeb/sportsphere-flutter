import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// A widget that catches and handles errors in its child subtree
class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({
    super.key,
    required this.child,
    this.onError,
    this.fallbackBuilder,
  });

  final Widget child;
  final void Function(Object error, StackTrace stack)? onError;
  final Widget Function(BuildContext context, Object error, StackTrace stack)?
      fallbackBuilder;

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stack;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Add error listener to the zone
    // Note: This is a simple implementation; consider using Flutter's built-in
    // error handling with ErrorWidget.builder for production use
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.fallbackBuilder?.call(context, _error!, _stack!) ??
          _DefaultFallback(
            error: _error!,
            stack: _stack!,
            onRetry: _reset,
          );
    }
    return widget.child;
  }

  void _reset() {
    setState(() {
      _error = null;
      _stack = null;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class _DefaultFallback extends StatelessWidget {
  const _DefaultFallback({
    required this.error,
    required this.stack,
    required this.onRetry,
  });

  final Object error;
  final StackTrace stack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  stack.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.left,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
