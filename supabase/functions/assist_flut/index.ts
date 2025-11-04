/**
 * BatiPilot IAssist - AI Agent Edge Function
 *
 * Routes:
 * - GET  /assist/status?run_id=xxx - Get run status for reconnection
 * - POST /assist/confirm - Confirm/deny user action
 * - POST /tools/upsert-embedding - Generate embedding for a tool (admin only)
 * - POST / - Start Agent Loop (default, legacy support)
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
import { handleStatus } from './status.ts';
import { handleConfirm } from './confirm.ts';
import { handleUpsertEmbedding } from './tools-embedding.ts';
import { agentLoop } from './agent-loop.ts';
import { createSSEResponse } from './sse.ts';

console.log('✅ Edge function "assist_flut" is up!');

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const pathname = url.pathname;

  try {
    // Extract auth and create Supabase client
    const authHeader = req.headers.get('Authorization') || '';
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    );

    // Get authenticated user
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const userId = user.id;

    // === ROUTING ===

    // GET /assist/status
    if (pathname.endsWith('/status') && req.method === 'GET') {
      return handleStatus(req, supabase, userId);
    }

    // POST /assist/confirm
    if (pathname.endsWith('/confirm') && req.method === 'POST') {
      return handleConfirm(req, supabase, userId);
    }

    // POST /tools/upsert-embedding (admin only - check secret header)
    if (pathname.endsWith('/tools/upsert-embedding') && req.method === 'POST') {
      const adminSecret = req.headers.get('X-Admin-Secret');
      const expectedSecret = Deno.env.get('ADMIN_SECRET');

      if (expectedSecret && adminSecret !== expectedSecret) {
        return new Response(JSON.stringify({ error: 'Unauthorized: invalid admin secret' }), {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      return handleUpsertEmbedding(req, supabase);
    }

    // POST / - Start Agent Loop (SSE stream)
    if (req.method === 'POST') {
      const body = await req.json().catch(() => ({}));
      const { userMessage, currentRoute, dryRun } = body;

      if (!userMessage) {
        return new Response(JSON.stringify({ error: 'userMessage required' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // Create execution context
      const ctx = {
        supabase,
        userId,
        runId: '', // Will be set in agentLoop
        traceId: crypto.randomUUID(),
        currentRoute: currentRoute || 'home',
      };

      // Start Agent Loop (returns SSE stream)
      const stream = await agentLoop(userMessage, ctx, dryRun !== false);

      return createSSEResponse(stream);
    }

    // 404 Not Found
    return new Response(JSON.stringify({ error: 'Not found' }), {
      status: 404,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error: any) {
    console.error('[assist_flut] Error:', error);
    return new Response(
      JSON.stringify({ error: `Internal error: ${error.message}` }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
