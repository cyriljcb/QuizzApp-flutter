import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_service.dart';
import '../providers/game_provider.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _pseudoController = TextEditingController();
  String? _selectedTheme;
  double _questionCount = 10;
  List<String> _themes = [];
  bool _loadingThemes = true;
  String? _themesError;

  @override
  void initState() {
    super.initState();
    _loadThemes();
  }

  Future<void> _loadThemes() async {
    try {
      final themes = await ApiService.getAvailableThemes();
      setState(() {
        _themes = themes;
        _loadingThemes = false;
      });
    } catch (_) {
      setState(() {
        _themesError = 'Impossible de charger les themes';
        _loadingThemes = false;
      });
    }
  }

  Future<void> _createRoom() async {
    final pseudo = _pseudoController.text.trim();
    if (pseudo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entre ton pseudo')),
      );
      return;
    }

    await ref.read(gameProvider.notifier).createRoom(pseudo);

    final current = ref.read(gameProvider);
    if (current is LobbyState && current.isHost) {
      ref.read(gameProvider.notifier).updateHostSettings(
            theme: _selectedTheme,
            questionCount: _questionCount.round(),
            clearTheme: _selectedTheme == null,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Creer une partie')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _pseudoController,
              decoration: const InputDecoration(
                labelText: 'Ton pseudo',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 32),
            Text('Theme', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_loadingThemes)
              const Center(child: CircularProgressIndicator())
            else if (_themesError != null)
              Text(_themesError!, style: const TextStyle(color: Colors.red))
            else
              DropdownButtonFormField<String?>(
                value: _selectedTheme,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                hint: const Text('Tous les themes'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tous les themes'),
                  ),
                  ..._themes.map(
                    (theme) => DropdownMenuItem<String?>(
                      value: theme,
                      child: Text(theme),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _selectedTheme = value),
              ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nombre de questions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${_questionCount.round()}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1565C0),
                      ),
                ),
              ],
            ),
            Slider(
              value: _questionCount,
              min: 5,
              max: 30,
              divisions: 25,
              label: _questionCount.round().toString(),
              onChanged: (value) => setState(() => _questionCount = value),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: _createRoom,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Creer la partie'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pseudoController.dispose();
    super.dispose();
  }
}
