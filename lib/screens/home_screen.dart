import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pseudoController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _pseudoController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    await ref.read(gameProvider.notifier).joinRoom(
          _codeController.text.trim().toUpperCase(),
          _pseudoController.text.trim(),
        );

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / Titre
                Icon(
                  Icons.quiz_rounded,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  '100% Logique',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rejoins la partie !',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 48),

                // Formulaire
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _pseudoController,
                        decoration: const InputDecoration(
                          labelText: 'Pseudo',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        textCapitalization: TextCapitalization.words,
                        maxLength: 20,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Entre un pseudo';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: 'Code de la room',
                          prefixIcon: Icon(Icons.tag_rounded),
                          hintText: 'ex : ABCD',
                          counterText: '',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 4,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                          _UpperCaseFormatter(),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().length != 4) {
                            return 'Le code doit contenir 4 caractères';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton.icon(
                              onPressed: _joinRoom,
                              icon: const Icon(Icons.login_rounded),
                              label: const Text(
                                'Rejoindre la partie',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}