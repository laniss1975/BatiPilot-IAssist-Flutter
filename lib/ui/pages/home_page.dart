import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_view/split_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:test1/providers/auth_provider.dart';
import 'package:test1/providers/supabase_connection_provider.dart';
import 'package:test1/providers/ai_chats_history_provider.dart';
import 'package:test1/ui/theme/app_theme.dart';
import '../widgets/left_pane.dart';
import '../widgets/right_pane.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final SplitViewController _splitViewController;

  @override
  void initState() {
    super.initState();
    _splitViewController = SplitViewController(weights: [0.75, 0.25]);
    // Sequence de demarrage corrigee
    Future.microtask(() async {
      await ref.read(supabaseConnectionProvider.notifier).autoConnect();
      // autoSignIn n'est appele que si autoConnect a potentiellement reussi
      await ref.read(authNotifierProvider.notifier).autoSignIn();
      
      // Charger l'historique des chats apres authentification
      await ref.read(aiChatsHistoryProvider.notifier).loadChats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.home_repair_service, color: AppTheme.primaryColor, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('BatiPilot IAssist'),
          ],
        ),
        actions: const [
          AuthStatusWidget(),
          SizedBox(width: 16),
        ],
      ),
      body: SplitView(
        controller: _splitViewController,
        viewMode: SplitViewMode.Horizontal,
        gripSize: 8,
        gripColor: AppTheme.messageBorder,
        gripColorActive: AppTheme.primaryColor,
        children: const [
          LeftPane(),
          RightPane(),
        ],
      ),
    );
  }
}

class AuthStatusWidget extends ConsumerWidget {
  const AuthStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final dbState = ref.watch(supabaseConnectionProvider);

    final statusColor = switch (dbState.status) {
      ConnectionStatus.connected => AppTheme.accentColor,
      ConnectionStatus.error => AppTheme.errorColor,
      _ => Colors.orange,
    };

    return authState.when(
      data: (state) {
        final user = state.session?.user;
        if (user == null) {
          return Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Connexion'),
                onPressed: () => _showLoginWizard(context, ref),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          );
        } else {
          return Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  user.email ?? 'Utilisateur',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout, size: 20),
                tooltip: 'Se deconnecter',
                onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
              ),
            ],
          );
        }
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(8.0),
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (err, stack) => const Icon(Icons.error, color: AppTheme.errorColor),
    );
  }
}

void _showLoginWizard(BuildContext context, WidgetRef ref) async {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final rememberMe = ValueNotifier<bool>(true);
  final form1 = GlobalKey<FormState>();

  // On pre-charge les identifiants de la BD s'ils existent
  final dbCredentials = await ref.read(supabaseConnectionProvider.notifier).getCredentials();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Etape 1/2 - Connexion a l\'appli'),
      content: Form(
        key: form1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email'), validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null),
            const SizedBox(height: 8),
            TextFormField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Mot de passe'), validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null),
            const SizedBox(height: 12),
            ValueListenableBuilder<bool>(
              valueListenable: rememberMe,
              builder: (context, value, _) => CheckboxListTile(
                title: const Text('Se souvenir de moi'),
                value: value,
                onChanged: (v) => rememberMe.value = v ?? value,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () {
            if (form1.currentState!.validate()) {
              Navigator.pop(context);
              _showSupabaseConfigDialog(
                context, 
                ref, 
                email: emailCtrl.text.trim(), 
                password: passCtrl.text, 
                rememberMe: rememberMe.value,
                initialUrl: dbCredentials?['url'],
                initialKey: dbCredentials?['key'],
              );
            }
          },
          child: const Text('Suivant'),
        ),
      ],
    ),
  );
}

void _showSupabaseConfigDialog(BuildContext context, WidgetRef ref, {required String email, required String password, required bool rememberMe, String? initialUrl, String? initialKey}) {
  final urlCtrl = TextEditingController(text: initialUrl);
  final keyCtrl = TextEditingController(text: initialKey);
  final rememberServer = ValueNotifier<bool>(true);
  final form2 = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (context) {
      bool submitting = false;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Etape 2/2 - Parametres Supabase'),
          content: Form(
            key: form2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'Supabase URL (https://...)'), validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null),
                const SizedBox(height: 8),
                TextFormField(controller: keyCtrl, decoration: const InputDecoration(labelText: 'Supabase ANON Key'), validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null),
                const SizedBox(height: 12),
                ValueListenableBuilder<bool>(
                  valueListenable: rememberServer,
                  builder: (context, value, _) => CheckboxListTile(
                    title: const Text('Memoriser ce serveur'),
                    value: value,
                    onChanged: (v) => rememberServer.value = v ?? value,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: submitting ? null : () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: submitting ? null : () async {
                if (!form2.currentState!.validate()) return;
                setState(() => submitting = true);
                try {
                  await ref.read(supabaseConnectionProvider.notifier).connect(urlCtrl.text.trim(), keyCtrl.text.trim(), persist: rememberServer.value);
                  await ref.read(authNotifierProvider.notifier).signIn(email, password, rememberMe);
                  
                  // Charger l'historique des chats apres connexion reussie
                  if (!context.mounted) return;
                  await ref.read(aiChatsHistoryProvider.notifier).loadChats();
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connexion reussie')));
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Echec: $e')));
                  setState(() => submitting = false);
                }
              },
              child: submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Se connecter'),
            ),
          ],
        ),
      );
    },
  );
}
