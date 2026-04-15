import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Créer
  final _createFormKey = GlobalKey<FormState>();
  final _createPseudoController = TextEditingController();

  // Rejoindre
  final _joinFormKey = GlobalKey<FormState>();
  final _joinPseudoController = TextEditingController();
  final _codeController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _createPseudoController.dispose();
    _joinPseudoController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    if (!_createFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await ref.read(gameProvider.notifier).createRoom(
          _createPseudoController.text.trim(),
        );
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _joinRoom() async {
    if (!_joinFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await ref.read(gameProvider.notifier).joinRoom(
          _codeController.text.trim().toUpperCase(),
          _joinPseudoController.text.trim(),
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
                const SizedBox(height: 32),

                // ── Logo / Titre ──────────────────────────────────────────
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
                const SizedBox(height: 48),

                // ── Onglets ───────────────────────────────────────────────
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Créer une room'),
                    Tab(text: 'Rejoindre'),
                  ],
                ),
                const SizedBox(height: 32),

                // ── Contenu des onglets ───────────────────────────────────
                SizedBox(
                  // Hauteur fixe pour éviter que le SingleChildScrollView
                  // entre en conflit avec le TabBarView
                  height: 280,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _CreateTab(
                        formKey: _createFormKey,
                        pseudoController: _createPseudoController,
                        isLoading: _isLoading,
                        onSubmit: _createRoom,
                      ),
                      _JoinTab(
                        formKey: _joinFormKey,
                        pseudoController: _joinPseudoController,
                        codeController: _codeController,
                        isLoading: _isLoading,
                        onSubmit: _joinRoom,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Onglet Créer ─────────────────────────────────────────────────────────────

class _CreateTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController pseudoController;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _CreateTab({
    required this.formKey,
    required this.pseudoController,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            controller: pseudoController,
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
          const SizedBox(height: 24),
          isLoading
              ? const CircularProgressIndicator()
              : ElevatedButton.icon(
                  onPressed: onSubmit,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'Créer la room',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
        ],
      ),
    );
  }
}

// ─── Onglet Rejoindre ─────────────────────────────────────────────────────────

class _JoinTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController pseudoController;
  final TextEditingController codeController;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _JoinTab({
    required this.formKey,
    required this.pseudoController,
    required this.codeController,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            controller: pseudoController,
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
            controller: codeController,
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
          const SizedBox(height: 24),
          isLoading
              ? const CircularProgressIndicator()
              : ElevatedButton.icon(
                  onPressed: onSubmit,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text(
                    'Rejoindre la partie',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
        ],
      ),
    );
  }
}

// ─── Formatter ────────────────────────────────────────────────────────────────

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}