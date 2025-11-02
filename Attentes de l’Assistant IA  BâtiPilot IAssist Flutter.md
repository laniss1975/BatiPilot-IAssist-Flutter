# Attentes de l’Assistant IA – BâtiPilot IAssist (Flutter)

**Version:** 1.0  
**Public cible:** Développeurs Flutter (Riverpod + Supabase)  
**Approche:** Assistant-first (l’application est pilotée par l’Assistant IA via des signaux)

---

## Table des matières

- [Vision et principes](#vision-et-principes)
- [Architecture globale](#architecture-globale)
- [Contrat de réponse IA (JSON strict)](#contrat-de-r%C3%A9ponse-ia-json-strict)
- [Persistance Supabase (tables flut)](#persistance-supabase-tables-flut)
- [Intégration Flutter](#int%C3%A9gration-flutter)
    - [5.1 Modèles de données Assistant](#51-mod%C3%A8les-de-donn%C3%A9es-assistant)
    - [5.2 Registre d’actions (Tools)](#52-registre-dactions-tools)
    - [5.3 AssistantController (orchestrateur)](#53-assistantcontroller-orchestrateur)
    - [5.4 Provider de chat (persisté)](#54-provider-de-chat-persist%C3%A9)
    - [5.5 Panneau d’assistant (UI)](#55-panneau-dassistant-ui)
    - [5.6 Navigation et actions UI](#56-navigation-et-actions-ui)
    - [5.7 Context Builder (MVP)](#57-context-builder-mvp)
- [Edge Function assist_flut](#edge-function-assist_flut)
- [Modules de l’Assistant IA](#modules-de-lassistant-ia)
- [Sécurité, RLS et secrets](#s%C3%A9curit%C3%A9-rls-et-secrets)
- [Gestion des erreurs et robustesse](#gestion-des-erreurs-et-robustesse)
- [Plan d’implémentation et checklist](#plan-dimpl%C3%A9mentation-et-checklist)
- [FAQ et pièges fréquents](#faq-et-pi%C3%A8ges-fr%C3%A9quents)
- [Extension: ajouter un nouveau Tool](#extension-ajouter-un-nouveau-tool)
- [Glossaire](#glossaire)

---

## Vision et principes

- **Assistant-first:** l’Assistant IA orchestre l’expérience. L’app exécute ses “signaux” (actions).
- **Contrat stable:** les réponses de l’IA sont en JSON strict (actions exécutables).
- **Séparation nette:**
    - Orchestrateur Flutter (AssistantController)
    - Registre de Tools (fonctions d’actions)
    - Edge Function (accès LLM sécurisé)
    - Persistance (nouvelles tables suffixées flut)
- **Évolutif:** ajouter un nouveau comportement = ajouter un Tool + activer un signal côté IA.
- **Traçable:** tous les messages et métadonnées (signaux) sont persistés.

## Architecture globale

### Composants clés:

- **AssistantPane (UI):** chat, actions, modules.
- **ai_chat_provider (Riverpod):** persistance des chats/messages.
- **AssistantController:** orchestre le flux (contexte → Edge → signaux → Tools → persistance).
- **Tools:** registre d’actions exécutables (NAVIGATE, UPDATE_METADATA, ADD_TRAVAIL, etc.).
- **Edge Function assist_flut:** proxy sécurisé vers les modèles IA.
- **Tables Supabase “flut”:** ai_chats_flut, ai_chat_messages_flut (RLS activée).

### Flux:

1. User tape un message → AssistantPane
2. AssistantController:
    - ensureCurrentChat, addUserMessage
    - buildContext, invoke assist_flut
    - parse JSON, exécute Tools
    - addAssistantMessage(meta = signaux/boutons)
3. UI affiche answer, actionButtons, navigationSignal

## Contrat de réponse IA (JSON strict)

L’Assistant IA DOIT répondre en JSON strict (response_format = json_object côté Edge Function).

### Structure:

```json
{
  "answer": "Texte à afficher à l'utilisateur",
  "contextUpdate": {
    "type": "ADD_TRAVAIL",
    "payload": { "titre": "Peinture salon", "quantite": 97, "unit": "M²", "prixMainOeuvre": 8.0, "prixFourniture": 4.5, "tauxTVA": 20 }
  },
  "navigationSignal": { "path": "/travaux", "message": "Je vous redirige." },
  "actionButtons": [
    { "type": "VALIDATE", "label": "✅ Valider", "data": { "action": "confirm" } },
    { "type": "MODIFY", "label": "✏️ Modifier", "data": { "action": "edit" } }
  ]
}
```

- **answer:** string court, utile, actionnable.
- **contextUpdate:** un seul signal d’action à exécuter via les Tools.
- **navigationSignal:** chemin interne à ouvrir (optionnel).
- **actionButtons:** actions utilisateur proposées (UI).

### Bonnes pratiques:

- Préférer des payloads “complets mais compacts”.
- Ne pas envoyer plusieurs contextUpdate en même temps (enchaîner si nécessaire).
- Toujours rester JSON valide.

## Persistance Supabase (tables flut)

Nouvelles tables (aucun conflit avec l’existant). Exécuter dans l’éditeur SQL:

```sql
create extension if not exists pgcrypto;

create table if not exists public.ai_chats_flut (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  module_name text not null default 'context',
  title text not null default 'Nouvelle discussion',
  provider_name text,
  model_name text,
  system_prompt_snapshot text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_chat_messages_flut (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.ai_chats_flut(id) on delete cascade,
  role text not null check (role in ('user','assistant','system')),
  content text not null,
  meta jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.handle_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_ai_chats_flut_updated_at on public.ai_chats_flut;
create trigger trg_ai_chats_flut_updated_at
before update on public.ai_chats_flut
for each row execute function public.handle_updated_at();

alter table public.ai_chats_flut enable row level security;
alter table public.ai_chat_messages_flut enable row level security;

-- Policies
 do $$ begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='ai_chats_flut' and policyname='ai_chats_flut_select_own'
  ) then
    create policy ai_chats_flut_select_own
      on public.ai_chats_flut for select to authenticated
      using (user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='ai_chats_flut' and policyname='ai_chats_flut_insert_own'
  ) then
    create policy ai_chats_flut_insert_own
      on public.ai_chats_flut for insert to authenticated
      with check (user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='ai_chats_flut' and policyname='ai_chats_flut_update_own'
  ) then
    create policy ai_chats_flut_update_own
      on public.ai_chats_flut for update to authenticated
      using (user_id = auth.uid()) with check (user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='ai_chats_flut' and policyname='ai_chats_flut_delete_own'
  ) then
    create policy ai_chats_flut_delete_own
      on public.ai_chats_flut for delete to authenticated
      using (user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='ai_chat_messages_flut' and policyname='ai_msgs_flut_select_by_chat_owner'
  ) then
    create policy ai_msgs_flut_select_by_chat_owner
      on public.ai_chat_messages_flut for select to authenticated
      using (exists (select 1 from public.ai_chats_flut c where c.id = chat_id and c.user_id = auth.uid()));
  end if;

  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='ai_chat_messages_flut' and policyname='ai_msgs_flut_insert_by_chat_owner'
  ) then
    create policy ai_msgs_flut_insert_by_chat_owner
      on public.ai_chat_messages_flut for insert to authenticated
      with check (exists (select 1 from public.ai_chats_flut c where c.id = chat_id and c.user_id = auth.uid()));
  end if;

  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='ai_chat_messages_flut' and policyname='ai_msgs_flut_delete_by_chat_owner'
  ) then
    create policy ai_msgs_flut_delete_by_chat_owner
      on public.ai_chat_messages_flut for delete to authenticated
      using (exists (select 1 from public.ai_chats_flut c where c.id = chat_id and c.user_id = auth.uid()));
  end if;
end $$;
```

### Optionnel:

- Bucket Storage: ai_uploads_flut (pour documents).
- Tables de configuration: ai_prompts_flut, ai_settings_flut (selon besoins).

## Intégration Flutter

### Pré-requis:

- flutter_riverpod, supabase_flutter, http
- Un provider supabase_connection_provider qui expose client

### 5.1 Modèles de données Assistant

```dart
class AssistantResponse {
  final String answer;
  final ContextUpdate? contextUpdate;
  final NavigationSignal? navigationSignal;
  final List<ActionButton> actionButtons;

  AssistantResponse({
    required this.answer,
    this.contextUpdate,
    this.navigationSignal,
    this.actionButtons = const [],
  });

  factory AssistantResponse.fromJson(Map<String, dynamic> json) {
    return AssistantResponse(
      answer: (json['answer'] ?? '').toString(),
      contextUpdate: json['contextUpdate'] is Map<String, dynamic>
          ? ContextUpdate.fromJson(json['contextUpdate'] as Map<String, dynamic>)
          : null,
      navigationSignal: json['navigationSignal'] is Map<String, dynamic>
          ? NavigationSignal.fromJson(json['navigationSignal'] as Map<String, dynamic>)
          : null,
      actionButtons: (json['actionButtons'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ActionButton.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toMeta() => {
    'contextUpdate': contextUpdate?.toJson(),
    'navigationSignal': navigationSignal?.toJson(),
    'actionButtons': actionButtons.map((e) => e.toJson()).toList(),
  };
}

class ContextUpdate {
  final String type;
  final Map<String, dynamic> payload;
  ContextUpdate({required this.type, required this.payload});

  factory ContextUpdate.fromJson(Map<String, dynamic> json) => ContextUpdate(
    type: (json['type'] ?? '').toString(),
    payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? {},
  );

  Map<String, dynamic> toJson() => {'type': type, 'payload': payload};
}

class NavigationSignal {
  final String path;
  final String? message;
  NavigationSignal({required this.path, this.message});

  factory NavigationSignal.fromJson(Map<String, dynamic> json) => NavigationSignal(
    path: (json['path'] ?? '/').toString(),
    message: json['message']?.toString(),
  );

  Map<String, dynamic> toJson() => {'path': path, 'message': message};
}

class ActionButton {
  final String type;
  final String label;
  final Map<String, dynamic>? data;
  ActionButton({required this.type, required this.label, this.data});

  factory ActionButton.fromJson(Map<String, dynamic> json) => ActionButton(
    type: (json['type'] ?? '').toString(),
    label: (json['label'] ?? '').toString(),
    data: (json['data'] as Map?)?.cast<String, dynamic>(),
  );

  Map<String, dynamic> toJson() => {'type': type, 'label': label, 'data': data};
}
```

### 5.2 Registre d’actions (Tools)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'assistant_models.dart';

typedef ToolHandler = Future<void> Function({
  required Map<String, dynamic> payload,
  required WidgetRef ref,
  required BuildContext context,
});

class AssistantToolsRegistry {
  final Map<String, ToolHandler> _handlers = {};

  void register(String type, ToolHandler handler) => _handlers[type] = handler;

  Future<void> dispatch(ContextUpdate update, WidgetRef ref, BuildContext context) async {
    final handler = _handlers[update.type];
    if (handler == null) {
      debugPrint('No tool for ${update.type}');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action non supportée: ${update.type}')));
      return;
    }
    await handler(payload: update.payload, ref: ref, context: context);
  }
}

// Exemples de Tools (stubs) à brancher plus tard sur votre logique métier
Future<void> navigateTool({
  required Map<String, dynamic> payload,
  required WidgetRef ref,
  required BuildContext context,
}) async {
  final path = (payload['path'] ?? '/').toString();
  // TODO: implémenter Navigator/GoRouter
  debugPrint('NAVIGATE 14 $path');
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Navigation vers $path')));
}

Future<void> updateMetadataTool({
  required Map<String, dynamic> payload,
  required WidgetRef ref,
  required BuildContext context,
}) async {
  // TODO: update state projet (provider) + persistance si nécessaire
  debugPrint('UPDATE_METADATA: $payload');
}

Future<void> addTravailTool({
  required Map<String, dynamic> payload,
  required WidgetRef ref,
  required BuildContext context,
}) async {
  // TODO: ajouter une prestation au projet en cours
  debugPrint('ADD_TRAVAIL: $payload');
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(' Prestation ajout�e9e')));
}

Future<void> createServiceTool({
  required Map<String, dynamic> payload,
  required WidgetRef ref,
  required BuildContext context,
}) async {
  // TODO: insertion service côté Supabase + retour ID si besoin
  debugPrint('CREATE_SERVICE: $payload');
}
```

### 5.3 AssistantController (orchestrateur)

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/supabase_connection_provider.dart';
import '../providers/ai_chat_provider.dart';
import 'assistant_models.dart';
import 'tools.dart';

class AssistantController {
  AssistantController(this.ref) {
    tools.register('NAVIGATE', navigateTool);
    tools.register('UPDATE_METADATA', updateMetadataTool);
    tools.register('ADD_TRAVAIL', addTravailTool);
    tools.register('CREATE_SERVICE', createServiceTool);
  }

  final WidgetRef ref;
  final tools = AssistantToolsRegistry();

  Future<String> _buildContextString({required String module}) async {
    // MVP: contexte minimal. Remplacer par un vrai ContextBuilder ciblé (module).
    return '=== CONTEXTE (module: $module) ===\nAucun projet sélectionné.\n=== FIN CONTEXTE ===';
  }

  Future<AssistantResponse> _callModel({
    required List<Map<String, String>> messages,
    required String module,
  }) async {
    final client = ref.read(supabaseConnectionProvider).client;
    if (client == null) {
      return AssistantResponse(answer: 'Pas de connexion Supabase.');
    }

    final contextStr = await _buildContextString(module: module);

    final payload = {
      'module': module,
      'response_format': 'json',
      'model': 'gpt-4o-mini',
      'messages': [
        {
          'role': 'system',
          'content': 'Tu es l’Assistant IA de BâtiPilot IAssist. Réponds toujours en JSON strict: {"answer": "...", "contextUpdate": {...}, "navigationSignal": {...}, "actionButtons": [...]}.',
        },
        {
          'role': 'user',
          'content': 'Contexte:\n$contextStr\n\nConversation:\n${messages.map((m) => "m.role: m.content").join("\n")}\n\nRéponds en JSON strict.'
        }
      ],
    };

    final resp = await client.functions.invoke('assist_flut', body: payload);

    // resp.data peut être Map<String, dynamic> ou String JSON
    if (resp.data is Map<String, dynamic>) {
      return AssistantResponse.fromJson(resp.data as Map<String, dynamic>);
    }
    if (resp.data is String) {
      try {
        final json = jsonDecode(resp.data as String) as Map<String, dynamic>;
        return AssistantResponse.fromJson(json);
      } catch (_) {
        return AssistantResponse(answer: (resp.data as String));
      }
    }
    return AssistantResponse(answer: 'Réponse inattendue du serveur.');
  }

  Future<void> handleUserMessage({
    required String text,
    required String module,
    required BuildContext context,
  }) async {
    final chat = ref.read(aiChatProvider.notifier);
    await chat.ensureCurrentChat(module: module);
    await chat.addUserMessage(text);

    final lastMessages = ref.read(aiChatProvider).messagesForModel(10);

    final res = await _callModel(messages: lastMessages, module: module);

    if (res.contextUpdate != null) {
      await tools.dispatch(res.contextUpdate!, ref, context);
    }
    if (res.navigationSignal != null) {
      await tools.dispatch(
        ContextUpdate(type: 'NAVIGATE', payload: {'path': res.navigationSignal!.path}),
        ref,
        context,
      );
      if (res.navigationSignal!.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.navigationSignal!.message!)));
      }
    }

    await chat.addAssistantMessage(res.answer, meta: res.toMeta());
  }
}

final assistantControllerProvider = Provider<AssistantController>((ref) {
  return AssistantController(ref);
});
```

### 5.4 Provider de chat (persisté)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_connection_provider.dart';

class AiMessage {
  final String id;
  final String role; // 'user' | 'assistant' | 'system'
  final String content;
  final Map<String, dynamic>? meta;
  final DateTime createdAt;
  AiMessage({required this.id, required this.role, required this.content, this.meta, required this.createdAt});
}

class AiChatState {
  final String? currentChatId;
  final String module;
  final List<AiMessage> messages;
  final bool loading;

  AiChatState({required this.currentChatId, required this.module, required this.messages, required this.loading});

  AiChatState copyWith({String? currentChatId, String? module, List<AiMessage>? messages, bool? loading}) => AiChatState(
    currentChatId: currentChatId ?? this.currentChatId,
    module: module ?? this.module,
    messages: messages ?? this.messages,
    loading: loading ?? this.loading,
  );
}

class AiChatNotifier extends StateNotifier<AiChatState> {
  AiChatNotifier(this._ref) : super(AiChatState(currentChatId: null, module: 'context', messages: [], loading: false));

  final Ref _ref;
  SupabaseClient? get _client => _ref.read(supabaseConnectionProvider).client;

  Future<void> ensureCurrentChat({required String module}) async {
    if (state.currentChatId != null && state.module == module) return;
    await createNewChat(module: module);
  }

  Future<void> createNewChat({required String module, String? title}) async {
    final client = _client;
    if (client == null) return;
    state = state.copyWith(loading: true);

    final userRes = await client.auth.getUser();
    final user = userRes.user;
    if (user == null) {
      state = state.copyWith(loading: false);
      return;
    }

    final res = await client
        .from('ai_chats_flut')
        .insert({
          'user_id': user.id,
          'module_name': module,
          'title': title ?? 'Nouvelle discussion',
          'provider_name': 'openai',
          'model_name': 'gpt-4o-mini',
        })
        .select()
        .single();

    if (res.error != null) {
      state = state.copyWith(loading: false);
      return;
    }

    final chatId = res.data['id'] as String;
    state = AiChatState(currentChatId: chatId, module: module, messages: [], loading: false);
  }

  Future<void> loadChat(String chatId, {required String module}) async {
    final client = _client;
    if (client == null) return;
    state = state.copyWith(loading: true);

    final msgs = await client
        .from('ai_chat_messages_flut')
        .select('id, role, content, meta, created_at')
        .eq('chat_id', chatId)
        .order('created_at', ascending: true);

    final list = (msgs.data as List<dynamic>? ?? [])
        .map((m) => AiMessage(
              id: m['id'] as String,
              role: m['role'] as String,
              content: (m['content'] ?? '').toString(),
              meta: (m['meta'] as Map?)?.cast<String, dynamic>(),
              createdAt: DateTime.parse(m['created_at'] as String),
            ))
        .toList();

    state = AiChatState(currentChatId: chatId, module: module, messages: list, loading: false);
  }

  Future<void> addUserMessage(String text) async {
    final client = _client;
    if (client == null || state.currentChatId == null) return;

    final res = await client
        .from('ai_chat_messages_flut')
        .insert({
          'chat_id': state.currentChatId,
          'role': 'user',
          'content': text,
          'meta': null
        })
        .select()
        .single();

    if (res.error == null) {
      final m = res.data;
      state = state.copyWith(messages: [
        ...state.messages,
        AiMessage(
          id: m['id'] as String,
          role: 'user',
          content: text,
          meta: null,
          createdAt: DateTime.parse(m['created_at'] as String),
        )
      ]);
    }
  }

  Future<void> addAssistantMessage(String text, {Map<String, dynamic>? meta}) async {
    final client = _client;
    if (client == null || state.currentChatId == null) return;

    final res = await client
        .from('ai_chat_messages_flut')
        .insert({
          'chat_id': state.currentChatId,
          'role': 'assistant',
          'content': text,
          'meta': meta,
        })
        .select()
        .single();

    if (res.error == null) {
      final m = res.data;
      state = state.copyWith(messages: [
        ...state.messages,
        AiMessage(
          id: m['id'] as String,
          role: 'assistant',
          content: text,
          meta: meta,
          createdAt: DateTime.parse(m['created_at'] as String),
        )
      ]);
    }
  }

  List<Map<String, String>> messagesForModel(int lastN) {
    final take = state.messages.length > lastN ? state.messages.sublist(state.messages.length - lastN) : state.messages;
    return take.map((m) => {'role': m.role, 'content': m.content}).toList();
  }
}

final aiChatProvider = StateNotifierProvider<AiChatNotifier, AiChatState>((ref) {
  return AiChatNotifier(ref);
});
```

### 5.5 Panneau d’assistant (UI)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../assistant/assistant_controller.dart';
import '../../providers/ai_chat_provider.dart';

class AssistantPane extends ConsumerStatefulWidget {
  const AssistantPane({super.key});
  @override
  ConsumerState<AssistantPane> createState() => _AssistantPaneState();
}

class _AssistantPaneState extends ConsumerState<AssistantPane> {
  final _ctrl = TextEditingController();
  String _module = 'context';
  bool _sending = false;

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(assistantControllerProvider).handleUserMessage(
            text: text,
            module: _module,
            context: context,
          );
      _ctrl.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(aiChatProvider);

    // Récupère les derniers actionButtons suggérés (si présents)
    final lastAssistantMeta = chat.messages.reversed
        .firstWhere(
          (m) => m.role == 'assistant' && m.meta != null,
          orElse: () => AiMessage(id: '', role: 'assistant', content: '', meta: null, createdAt: DateTime.now()),
        )
        .meta;

    final actionButtons = (lastAssistantMeta?['actionButtons'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Assistant IA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            DropdownButton<String>(
              value: _module,
              items: const [
                DropdownMenuItem(value: 'context', child: Text('Assistant Contextuel')),
                DropdownMenuItem(value: 'imports', child: Text('Assistant Import')),
                DropdownMenuItem(value: 'reports', child: Text('Assistant Rapports')),
                DropdownMenuItem(value: 'general', child: Text('Assistant Généraliste')),
              ],
              onChanged: (v) => v == null ? null : setState(() => _module = v),
            ),
          ]),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: chat.messages.length,
              itemBuilder: (ctx, i) {
                final m = chat.messages[i];
                final isUser = m.role == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blueGrey[100] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.content),
                        if (!isUser && m.meta != null && (m.meta!['navigationSignal']?['message'] != null))
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text('➡️ ${m.meta!['navigationSignal']['message']}',
                                style: const TextStyle(color: Colors.grey)),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (actionButtons.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, top: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: actionButtons.map((btn) {
                  final label = (btn['label'] ?? 'Action').toString();
                  final type = (btn['type'] ?? '').toString();
                  // final data = (btn['data'] as Map?)?.cast<String, dynamic>() ?? {};
                  return ActionChip(
                    label: Text(label),
                    onPressed: () {
                      // Exemple simple: renvoyer la volonté utilisateur sous forme de message
                      ref.read(assistantControllerProvider).handleUserMessage(
                        text: 'Action choisie: $type',
                        module: _module,
                        context: context,
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 8),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.attach_file), tooltip: 'Joindre un fichier'),
          Expanded(
            child: TextField(
              controller: _ctrl,
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Écrire un message...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.fromLTRB(12, 12, 12, 12),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0, bottom: 4),
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, size: 18),
              label: const Text('Envoyer'),
            ),
          ),
        ],
      ),
    );
  }
}
```

### 5.6 Navigation et actions UI

Exemple d’intégration GoRouter avec NAVIGATE:

```dart
// tools.dart
import 'package:go_router/go_router.dart';

Future<void> navigateTool({
  required Map<String, dynamic> payload,
  required WidgetRef ref,
  required BuildContext context,
}) async {
  final path = (payload['path'] ?? '/').toString();
  if (GoRouter.of(context).canPop()) {
    GoRouter.of(context).go(path);
  } else {
    GoRouter.of(context).go(path);
  }
}
```

### 5.7 Context Builder (MVP)

Idée: créer un provider/fichier dédié qui compose un contexte minimum puis l’enrichit.

```dart
Future<String> buildContextForModule({
  required String module,
  required SupabaseClient client,
}) async {
  // TODO: injecter des données pertinentes sans mentionner les anciennes tables
  // Ex: prendre uniquement le nom du projet courant depuis l’état local.
  final projectName = 'Projet courant inconnu'; // à remplacer
  return '''
=== CONTEXTE ASSISTANT (MODULE: $module) ===
Projet: $projectName
Note: Contexte MVP (à enrichir)
=== FIN CONTEXTE ===
''';
}
```

## Edge Function assist_flut

But: centraliser l’accès au LLM (sécurité des clés, contrôle des modèles).  
Dossier: supabase/functions/assist_flut/index.ts

```typescript
// Deno (Edge Functions)
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }
  if (!OPENAI_API_KEY) {
    return new Response(JSON.stringify({ error: "OPENAI_API_KEY missing" }), {
      status: 500, headers: { "Content-Type": "application/json" },
    });
  }
  try {
    const { messages, model = "gpt-4o-mini", response_format = "json" } = await req.json();

    const r = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        temperature: 0.2,
        messages,
        response_format: response_format === "json" ? { type: "json_object" } : undefined
      }),
    });

    if (!r.ok) {
      const err = await r.text();
      return new Response(JSON.stringify({ error: err }), {
        status: r.status, headers: { "Content-Type": "application/json" },
      });
    }

    const data = await r.json();
    const content = data?.choices?.[0]?.message?.content ?? "{}";
    return new Response(content, { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { "Content-Type": "application/json" },
    });
  }
});
```

### Déploiement:

```bash
supabase functions deploy assist_flut
supabase secrets set --env prod OPENAI_API_KEY=xxx
```

## Modules de l’Assistant IA

Modules cibles (sélecteur dans l’UI):

- context: assistant contextuel (projet, navigation, modifications)
- imports: assistant d’import de documents (analyse → validation → CSV)
- reports: assistance rapports/études (rédaction, synthèses, exports)
- general: questions générales et tutoriels

Outils typiques:

NAVIGATE, UPDATE_METADATA, ADD_TRAVAIL, CREATE_CLIENT, CREATE_SERVICE, GENERATE_CSV, SHOW_REVIEW, CREATE_REPORT, EXPORT_PDF

## Sécurité, RLS et secrets

- Ne jamais exposer les clés LLM dans l’app. Toujours via assist_flut.
- RLS activé sur toutes les tables flut (voir SQL).
- Journaux/metadonnées: stocker actionButtons, navigationSignal, contextUpdate exécutés dans meta.
- (Optionnel) Limiter le débit (rate limit) côté Edge Functions.

## Gestion des erreurs et robustesse

- JSON invalide: fallback answer et log clair.
- Client Supabase indisponible: message “Pas de connexion Supabase.”, désactiver bouton Envoyer.
- Temps de réponse long: spinner et timeout côté app si besoin.
- Desktop (Windows): la session Supabase peut ne pas persister nativement; l’auto-signin via SecureStorage est recommandé.

### Exemple de parsing robuste:

```dart
AssistantResponse parseAssistantResponse(dynamic data) {
  try {
    if (data is Map<String, dynamic>) return AssistantResponse.fromJson(data);
    if (data is String) return AssistantResponse.fromJson(jsonDecode(data) as Map<String, dynamic>);
    return AssistantResponse(answer: 'Réponse inattendue');
  } catch (e) {
    return AssistantResponse(answer: 'Réponse non valide (JSON).');
  }
}
```

## Plan d’implémentation et checklist

### Semaine 1 (MVP)

- Exécuter SQL flut (ai_chats_flut, ai_chat_messages_flut)
- Déployer assist_flut + secret OPENAI_API_KEY
- Intégrer AssistantPane, ai_chat_provider, AssistantController, Tools (stubs)
- Premier run: envoyer/recevoir un message IA → persister

### Semaine 2

- ContextBuilder minimal par module
- ActionButtons cliquables → exécution d’un Tool
- NAVIGATE relié au routeur (GoRouter ou Navigator)

### Semaine 3

- ADD_TRAVAIL, UPDATE_METADATA reliés à votre logique projet
- CREATE_SERVICE branché sur insert Supabase (table cible) + feedback UI
- Génération CSV (GENERATE_CSV) (Storage)

### Semaine 4

- Paramétrage modèles par module (ai_settings_flut)
- Prompts système (ai_prompts_flut) + snapshot dans le chat

## FAQ et pièges fréquents

**Q: L’IA renvoie du texte non-JSON**  
R: enforce response_format: json_object côté assist_flut, parse avec try/catch, fallback answer.

**Q: “Client Supabase non initialisé.”**  
R: attendre la connexion (provider), désactiver le bouton tant que pas connecté.

**Q: RLS bloque “connect”**  
R: ne pas faire de SELECT de test dans connect(); la validation se fait au sign-in utilisateur.

**Q: Où brancher la logique métier ?**  
R: exclusivement dans les Tools (fichier tools.dart) pour éviter l’éparpillement.

## Extension: ajouter un nouveau Tool

Définir le signal côté IA (ex: "type": "CREATE_CLIENT").

Implémenter le Tool:

```dart
Future<void> createClientTool({
  required Map<String, dynamic> payload,
  required WidgetRef ref,
  required BuildContext context,
}) async {
  final client = ref.read(supabaseConnectionProvider).client;
  if (client == null) return;
  // TODO: valider payload (nom, email, etc.)
  final res = await client.from('clients_flut').insert({
    'name': payload['name'],
    'email': payload['email'],
  }).select().single();
  if (res.error != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur création client')));
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Client créé')));
}
```

Enregistrer dans AssistantController:

```dart
tools.register('CREATE_CLIENT', createClientTool);
```

L’IA peut maintenant proposer contextUpdate: { "type": "CREATE_CLIENT", ... }.

## Glossaire

- **Assistant IA:** l’agent conversationnel qui pilote l’app via des signaux JSON.
- **Module:** périmètre fonctionnel (“context”, “imports”, “reports”, “general”).
- **Tool:** fonction d’action exécutée dans l’app (plugin).
- **Signal:** instruction structurée envoyée par l’IA (contextUpdate, navigationSignal, actionButtons).
- **Context Builder:** compose le contexte métier injecté au LLM.
- **Edge Function:** fonction serverless Supabase (assist_flut) qui appelle le LLM.
- **Tables flut:** nouvelles tables dédiées à Flutter (ai_chats_flut, ai_chat_messages_flut).
