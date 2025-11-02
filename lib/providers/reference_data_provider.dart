import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test1/models/ai_model_model.dart';
import 'package:test1/models/ai_provider_model.dart';
import 'package:test1/models/company_model.dart';
import 'package:test1/models/client_model.dart';
import 'package:test1/providers/auth_provider.dart';
import 'package:test1/providers/supabase_connection_provider.dart';

// --- Gestion des Sociétés ---
class CompaniesNotifier extends AsyncNotifier<List<Company>> {
  @override
  Future<List<Company>> build() async {
    final supabaseClient = ref.watch(supabaseConnectionProvider).client;
    final authState = ref.watch(authStateProvider);
    if (supabaseClient == null || authState.value?.session?.user == null) return [];
    
    final response = await supabaseClient.from('companies').select();
    return response.map((item) => Company.fromJson(item)).toList();
  }

  Future<void> addCompany({
    required String name,
    String? address,
    String? city,
    String? postalCode,
    String? email,
    String? tel1,
    String? siret,
    String? tvaIntracom,
  }) async {
    final supabaseClient = ref.read(supabaseConnectionProvider).client;
    if (supabaseClient == null) throw Exception('Client Supabase non initialisé');
    
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) throw Exception('Utilisateur non authentifié');

    await supabaseClient.from('companies').insert({
      'name': name,
      'address': address,
      'city': city,
      'postal_code': postalCode,
      'email': email,
      'tel1': tel1,
      'siret': siret,
      'tva_intracom': tvaIntracom,
      'user_id': userId,
    });
    
    ref.invalidateSelf();
  }
}
final companiesProvider = AsyncNotifierProvider<CompaniesNotifier, List<Company>>(CompaniesNotifier.new);

// --- Gestion des Clients ---
class ClientsNotifier extends AsyncNotifier<List<Client>> {
  @override
  Future<List<Client>> build() async {
    final supabaseClient = ref.watch(supabaseConnectionProvider).client;
    final authState = ref.watch(authStateProvider);
    if (supabaseClient == null || authState.value?.session?.user == null) return [];

    final response = await supabaseClient.from('clients').select();
    return response.map((item) => Client.fromJson(item)).toList();
  }

  Future<void> addClient({
    required String nom,
    String? prenom,
    String? adresse,
    String? codePostal,
    String? ville,
    String? tel1,
    String? email,
  }) async {
    final supabaseClient = ref.read(supabaseConnectionProvider).client;
    if (supabaseClient == null) throw Exception('Client Supabase non initialisé');
    
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) throw Exception('Utilisateur non authentifié');

    await supabaseClient.from('clients').insert({
      'nom': nom,
      'prenom': prenom,
      'adresse': adresse,
      'code_postal': codePostal,
      'ville': ville,
      'tel1': tel1,
      'email': email,
      'user_id': userId,
    });

    ref.invalidateSelf();
  }
}
final clientsProvider = AsyncNotifierProvider<ClientsNotifier, List<Client>>(ClientsNotifier.new);


// --- Données de Référence pour l'IA ---

final aiProvidersProvider = FutureProvider<List<AiProvider>>((ref) async {
  final supabase = ref.watch(supabaseConnectionProvider).client;
  if (supabase == null) return [];

  try {
    final response = await supabase.from('ai_providers').select();
    return response.map((item) => AiProvider.fromJson(item)).toList();
  } catch (e) {
    rethrow;
  }
});

final aiModelsProvider = FutureProvider<List<AiModel>>((ref) async {
  final supabase = ref.watch(supabaseConnectionProvider).client;
  if (supabase == null) return [];
  
  final response = await supabase
      .from('ai_models')
      .select(); // TOUS les modèles, sans jointure
      
  return response.map((item) => AiModel.fromJson(item)).toList();
});
