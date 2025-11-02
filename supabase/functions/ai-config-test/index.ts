// supabase/functions/ai-config-test/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

console.log('Edge function "ai-config-test" is up!');

// Modèle de la réponse attendue de ai-keys-manager pour l'action 'get-key'
interface KeyResponse {
  success: boolean;
  apiKey?: string;
  error?: string;
}

serve(async (req) => {
  // Gère la requête CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. On récupère le header d'authentification de l'appel original du client Flutter
    const authHeader = req.headers.get('Authorization')!
    if (!authHeader) {
      throw new Error('Missing Authorization header');
    }

    // 2. Créer un client Supabase avec les droits de l'utilisateur qui fait l'appel
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    // 3. Récupérer l'utilisateur depuis le JWT (c'est la méthode sécurisée)
    const { data: { user } } = await supabaseClient.auth.getUser()
    if (!user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: corsHeaders })
    }

    // 4. Lire la configuration de modèle active pour cet utilisateur
    const { data: config, error: configError } = await supabaseClient
      .from('ai_provider_configs')
      .select('provider_name, model_name')
      .eq('user_id', user.id)
      .eq('module_name', 'global')
      .eq('is_active', true)
      .single()

    if (configError) throw configError
    if (!config) throw new Error('Aucune configuration de modèle actif trouvée.')

    // 5. Appeler ai-keys-manager en interne pour obtenir la clé
    const keysManagerUrl = `${Deno.env.get('SUPABASE_URL')!}/functions/v1/ai-keys-manager`;
    
    const keyResponse = await fetch(keysManagerUrl, {
      method: 'POST',
      headers: {
        'Authorization': authHeader, // On réutilise le header d'authentification de l'utilisateur
        'x-internal-token': Deno.env.get('EDGE_FUNCTIONS_SECRET')!, // Jeton secret pour prouver que l'appel est interne
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        action: 'get-key',
        provider: config.provider_name
        // Plus besoin de passer user_id, `ai-keys-manager` le déduira du JWT
      })
    });

    if (!keyResponse.ok) {
        const errorBody = await keyResponse.json();
        throw new Error(`Erreur de ai-keys-manager: ${errorBody.error || JSON.stringify(errorBody)}`);
    }

    const keyData: KeyResponse = await keyResponse.json();
    
    if (!keyData.success || !keyData.apiKey) {
      return new Response(
        JSON.stringify({
          api_key_ok: false,
          model_accessible: false,
          details: `Clé API non trouvée ou vide via ai-keys-manager: ${keyData.error || 'Raison inconnue'}`
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const apiKey = keyData.apiKey;

    // 6. Faire un ping minimal du modèle configuré
    let modelAccessible = false;
    let details = 'Ping test non implémenté pour ce fournisseur.';

    if (config.provider_name === 'openai') {
      const pingResponse = await fetch('https://api.openai.com/v1/models', {
        headers: { 'Authorization': `Bearer ${apiKey}` }
      });
      modelAccessible = pingResponse.ok;
      details = `Ping vers l'API OpenAI a retourné le statut : ${pingResponse.status}`;
    }
    // TODO: Ajouter des "pings" pour les autres fournisseurs (google, anthropic, etc.) ici

    // 7. Retourner le résultat final
    const result = {
      api_key_ok: true,
      model_accessible: modelAccessible,
      details: details
    };

    return new Response(
      JSON.stringify(result),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error in ai-config-test:', error.message);
    return new Response(
      JSON.stringify({ error: `Erreur interne: ${error.message}` }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
