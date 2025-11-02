import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

console.log('Edge function "ai-keys-manager" is up!');

// Fonction pour chiffrer une clé API (simple base64 pour l'exemple, utilisez une vraie encryption en prod)
function encryptKey(apiKey: string): string {
  return btoa(apiKey);
}

// Fonction pour déchiffrer une clé API
function decryptKey(encryptedKey: string): string {
  return atob(encryptedKey);
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { action, provider, model, keyName, apiKey, notes, setAsActive, keyId, newApiKey } = await req.json();
    const authHeader = req.headers.get('Authorization')!
    if (!authHeader) throw new Error('Missing Authorization header');

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user } } = await supabaseClient.auth.getUser();
    if (!user) throw new Error('Unauthorized');

    // --- ADD KEY ---
    if (action === 'add-key') {
      if (!provider || !keyName || !apiKey) {
        throw new Error('Missing required fields: provider, keyName, apiKey');
      }

      // Chiffrer la clé
      const encryptedKey = encryptKey(apiKey);

      // Si setAsActive, désactiver les autres clés du même provider/model
      if (setAsActive) {
        await supabaseClient
          .from('user_api_keys')
          .update({ is_active: false })
          .eq('user_id', user.id)
          .eq('provider_key', provider)
          .eq('model_key', model || null);
      }

      // Insérer la nouvelle clé avec la clé chiffrée
      const { error: insertError } = await supabaseClient
        .from('user_api_keys')
        .insert({
          user_id: user.id,
          provider_key: provider,
          model_key: model,
          key_name: keyName,
          notes: notes,
          is_active: setAsActive ?? false,
          encrypted_key: encryptedKey,
        });

      if (insertError) throw insertError;

      return new Response(
        JSON.stringify({ success: true }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // --- GET KEY ---
    if (action === 'get-key') {
      if (!provider) throw new Error('Missing provider');

      // Récupérer la clé active pour ce provider depuis user_api_keys
      const { data: keyData, error: keyError } = await supabaseClient
        .from('user_api_keys')
        .select('encrypted_key')
        .eq('user_id', user.id)
        .eq('provider_key', provider)
        .eq('is_active', true)
        .limit(1)
        .single();

      if (keyError || !keyData || !keyData.encrypted_key) {
        return new Response(
          JSON.stringify({ success: false, error: 'No active API key found for this provider' }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      const decryptedKey = decryptKey(keyData.encrypted_key);

      return new Response(
        JSON.stringify({ success: true, apiKey: decryptedKey }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // --- UPDATE KEY ---
    if (action === 'update-key') {
      if (!keyId) throw new Error('Missing keyId');

      const updates: any = {};
      if (keyName) updates.key_name = keyName;
      if (notes !== undefined) updates.notes = notes;
      if (newApiKey) updates.encrypted_key = encryptKey(newApiKey);

      const { error: updateError } = await supabaseClient
        .from('user_api_keys')
        .update(updates)
        .eq('id', keyId)
        .eq('user_id', user.id);

      if (updateError) throw updateError;

      return new Response(
        JSON.stringify({ success: true }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // --- DELETE KEY ---
    if (action === 'delete-key') {
      if (!keyId) throw new Error('Missing keyId');

      const { error: deleteError } = await supabaseClient
        .from('user_api_keys')
        .delete()
        .eq('id', keyId)
        .eq('user_id', user.id);

      if (deleteError) throw deleteError;

      return new Response(
        JSON.stringify({ success: true }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    throw new Error(`Action non supportée: ${action}`);

  } catch (error) {
    console.error('Error in ai-keys-manager:', error.message);
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
