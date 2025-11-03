import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

console.log('Edge function "assist_flut" is up!');

interface KeyResponse {
  success: boolean;
  apiKey?: string;
  error?: string;
}

const SYSTEM_PROMPT = `Tu es BâtiPilot IAssist, un assistant expert en gestion de projets de construction et rénovation.
Ton rôle est d'aider les utilisateurs à créer et gérer leurs devis de manière efficace.
Tu DOIS répondre exclusivement au format JSON en respectant ce contrat strict :
{
  "answer": "Ta réponse textuelle à l'utilisateur, toujours concise et professionnelle.",
  "contextUpdate": {
    "type": "NOM_DE_L_ACTION",
    "payload": { "cle": "valeur" }
  },
  "navigationSignal": null,
  "actionButtons": []
}
Si aucune action n'est nécessaire, les champs contextUpdate, navigationSignal, et actionButtons doivent être null ou un tableau vide.`;

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { module, userMessage, projectState, systemPrompt } = await req.json();
    const authHeader = req.headers.get('Authorization')!
    if (!authHeader) throw new Error('Missing Authorization header');

    // --- 1. Authentification et Configuration ---
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )
    const { data: { user } } = await supabaseClient.auth.getUser();
    if (!user) throw new Error('Unauthorized');

    // Requête pour obtenir la configuration active
    const { data: configData, error: configError } = await supabaseClient
      .from('ai_provider_configs')
      .select('provider_name, model_name')
      .eq('user_id', user.id)
      .eq('module_name', 'global')
      .eq('is_active', true)
      .single();

    if (configError) throw configError;
    if (!configData) throw new Error('Configuration de modèle introuvable.');

    // Requête séparée pour obtenir les détails du fournisseur
    const { data: providerDetails, error: providerError } = await supabaseClient
      .from('ai_providers')
      .select('provider_key, api_endpoint, api_auth_method, api_headers')
      .eq('provider_key', configData.provider_name)
      .single();

    if (providerError) throw providerError;
    if (!providerDetails) throw new Error('Détails du fournisseur introuvables.');

    // --- 2. Récupération de la clé API ---
    const keysManagerUrl = `${Deno.env.get('SUPABASE_URL')!}/functions/v1/ai-keys-manager`;
    const keyResponse = await fetch(keysManagerUrl, {
      method: 'POST',
      headers: {
        'Authorization': authHeader,
        'x-internal-token': Deno.env.get('EDGE_FUNCTIONS_SECRET')!,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ action: 'get-key', provider: providerDetails.provider_key })
    });

    if (!keyResponse.ok) {
      const errorBody = await keyResponse.json();
      throw new Error(`Erreur de ai-keys-manager: ${errorBody.error || JSON.stringify(errorBody)}`);
    }

    const keyData: KeyResponse = await keyResponse.json();
    if (!keyData.success || !keyData.apiKey) {
      throw new Error(`Clé API non trouvée via ai-keys-manager: ${keyData.error || 'Raison inconnue'}`);
    }
    const apiKey = keyData.apiKey;

    // --- 3. Construction et Appel au LLM ---
    const model = configData.model_name;
    console.log(`[assist_flut] Modèle utilisé: ${model} (provider: ${providerDetails.provider_key})`);
    let endpoint = providerDetails.api_endpoint;
    const headers = new Headers(providerDetails.api_headers || {});
    headers.set('Content-Type', 'application/json');

    // Construction de l'endpoint selon le provider
    if (providerDetails.provider_key === 'google') {
      // Pour Google: endpoint/{model}:generateContent?key={apiKey}
      endpoint = `${endpoint}/${model}:generateContent?key=${apiKey}`;
    } else if (providerDetails.provider_key === 'openai') {
      // Pour OpenAI: endpoint/chat/completions
      endpoint = endpoint.replace('/models', '/chat/completions');
      headers.set('Authorization', `Bearer ${apiKey}`);
    } else if (providerDetails.api_auth_method === 'bearer') {
      headers.set('Authorization', `Bearer ${apiKey}`);
    } else if (providerDetails.api_auth_method === 'api_key_header') {
      headers.set('x-api-key', apiKey);
    } else if (providerDetails.api_auth_method === 'query_param') {
      endpoint += `?key=${apiKey}`;
    }

    const fullPrompt = `Contexte du projet (état JSON actuel):
${JSON.stringify(projectState, null, 2)}

Historique de la conversation:
<non implémenté pour l'instant>

Message de l'utilisateur:
"${userMessage}"`;

    // Utiliser le prompt système fourni ou le fallback
    const effectiveSystemPrompt = systemPrompt || SYSTEM_PROMPT;
    console.log(`[assist_flut] Utilisation du prompt système: ${systemPrompt ? 'depuis BDD' : 'hardcodé (fallback)'}`);

    // Construction du body selon le provider
    let requestBody;
    if (providerDetails.provider_key === 'google') {
      // Format Google Gemini
      requestBody = {
        contents: [{
          parts: [{
            text: `${effectiveSystemPrompt}\n\n${fullPrompt}`
          }]
        }],
        generationConfig: {
          temperature: 0.5,
          maxOutputTokens: 1500,
        }
      };
    } else {
      // Format OpenAI (et compatibles)
      requestBody = {
        model: model,
        messages: [
          { role: 'system', content: effectiveSystemPrompt },
          { role: 'user', content: fullPrompt }
        ],
        temperature: 0.5,
        max_tokens: 1500,
      };
    }

    const llmResponse = await fetch(endpoint, {
      method: 'POST',
      headers: headers,
      body: JSON.stringify(requestBody)
    });

    if (!llmResponse.ok) {
      throw new Error(`Erreur de l'API du LLM: ${llmResponse.status} ${await llmResponse.text()}`);
    }

    // --- 4. Parsing et renvoi de la réponse ---
    const llmResult = await llmResponse.json();
    let assistantReply;
    
    if (providerDetails.provider_key === 'google') {
      // Format de réponse Google Gemini
      assistantReply = llmResult.candidates[0].content.parts[0].text;
    } else {
      // Format de réponse OpenAI (et compatibles)
      assistantReply = llmResult.choices[0].message.content;
    }
    
    // Nettoyer la réponse (enlever les balises markdown JSON si présentes)
    let cleanedReply = assistantReply.trim();
    if (cleanedReply.startsWith('```json')) {
      cleanedReply = cleanedReply.replace(/^```json\s*/i, '').replace(/\s*```$/i, '');
    } else if (cleanedReply.startsWith('```')) {
      cleanedReply = cleanedReply.replace(/^```\s*/i, '').replace(/\s*```$/i, '');
    }
    
    let finalResponse;
    try {
      finalResponse = JSON.parse(cleanedReply);
    } catch (e) {
      // Si le LLM n'a pas répondu en JSON, on encapsule sa réponse
      finalResponse = { answer: assistantReply, contextUpdate: null, navigationSignal: null, actionButtons: [] };
    }

    return new Response(
      JSON.stringify(finalResponse),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error in assist_flut:', error.message);
    return new Response(
      JSON.stringify({ error: `Erreur interne: ${error.message}` }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
