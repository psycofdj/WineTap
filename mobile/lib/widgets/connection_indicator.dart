import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/server_provider.dart';

/// Displays the local server's IP:port address in the AppBar.
class ServerIndicator extends StatelessWidget {
  const ServerIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final address = context.watch<ServerProvider>().serverAddress;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi, size: 14),
        const SizedBox(width: 4),
        Text(address, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
