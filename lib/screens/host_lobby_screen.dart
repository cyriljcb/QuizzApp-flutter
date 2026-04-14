import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'lobby_screen.dart';

class HostLobbyScreen extends ConsumerWidget {
  const HostLobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const LobbyScreen();
  }
}
