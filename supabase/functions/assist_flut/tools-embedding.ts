/**
 * /tools/upsert-embedding endpoint
 *
 * Generates and stores embedding for a Tool to enable semantic search (V2).
 * Called from Tools Management UI when creating/editing a Tool.
 *
 * Security: Should be protected with admin-only access or internal secret.
 */

export async function handleUpsertEmbedding(req: Request, supabase: any) {
  const body = await req.json().catch(() => ({}));
  const { tool_id, key } = body || {};

  if (!tool_id && !key) {
    return json({ error: 'tool_id or key required' }, 400);
  }

  // 1) Load tool
  const q = supabase
    .from('ai_tools')
    .select('*')
    .eq(key ? 'key' : 'id', key ?? tool_id)
    .single();

  const { data: tool, error } = await q;
  if (error || !tool) {
    return json({ error: 'TOOL_NOT_FOUND' }, 404);
  }

  // 2) Build text summary for embedding
  const schemaProps = Object.keys(tool.parameters_schema?.properties ?? {});
  const summary = [
    tool.name,
    tool.description,
    `category:${tool.category ?? ''}`,
    `risk:${tool.risk_level}`,
    `confirm:${tool.confirmation_policy}`,
    `params:[${schemaProps.join(',')}]`,
    tool.tags?.length ? `tags:[${tool.tags.join(',')}]` : '',
  ]
    .filter(Boolean)
    .join('\n');

  // 3) Generate embedding
  const model = Deno.env.get('EMBEDDING_MODEL') || 'text-embedding-3-small';
  const apiKey = Deno.env.get('OPENAI_API_KEY');

  if (!apiKey) {
    return json({ error: 'OPENAI_API_KEY not configured' }, 500);
  }

  const emb = await getEmbeddingOpenAI(summary, model, apiKey);
  if (!emb) {
    return json({ error: 'EMBEDDING_FAILED' }, 500);
  }

  // 4) Upsert embedding
  const { error: upErr } = await supabase
    .from('ai_tool_embeddings')
    .upsert({
      tool_id: tool.id,
      embedding: emb,
      text_summary: summary,
      updated_at: new Date().toISOString(),
    });

  if (upErr) {
    return json({ error: 'UPSERT_FAILED', details: upErr.message }, 500);
  }

  return json({ success: true, tool_id: tool.id }, 200);
}

async function getEmbeddingOpenAI(
  text: string,
  model: string,
  apiKey: string
): Promise<number[] | null> {
  try {
    const resp = await fetch('https://api.openai.com/v1/embeddings', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ model, input: text }),
    });

    if (!resp.ok) {
      console.error('[embeddings] OpenAI API error:', resp.status, await resp.text());
      return null;
    }

    const j = await resp.json();
    return j?.data?.[0]?.embedding ?? null;
  } catch (e) {
    console.error('[embeddings] Error:', e);
    return null;
  }
}

function json(obj: any, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
