/**
 * /assist/status endpoint
 *
 * Reconstructs the state of an Agent run for:
 * - UI reconnection after SSE drop
 * - Status polling
 * - Run history display
 */

import { maskPII } from './utils.ts';

export type RunStatus = 'started'|'planning'|'waiting_confirmation'|'executing'|'succeeded'|'failed'|'cancelled'|'expired';

export type StatusResponse = {
  run_id: string;
  status: RunStatus;
  plan?: any;
  steps_completed?: number;
  tools_invoked?: Array<{
    tool_key: string;
    args_preview: Record<string, any>;
    result_preview?: Record<string, any> | null;
    duration_ms?: number | null;
    success: boolean | null;
    at: string;
  }>;
  answer?: string | null;
  actions?: any[] | null;
  error?: { code: string; message: string } | null;
};

function maskPreview(obj: any): any {
  try {
    const s = JSON.stringify(obj);
    return JSON.parse(maskPII(s));
  } catch {
    return obj;
  }
}

export async function handleStatus(req: Request, supabase: any, userId: string) {
  const { searchParams } = new URL(req.url);
  const runId = searchParams.get('run_id');

  if (!runId) {
    return json({ error: 'run_id required' }, 400);
  }

  // 1) Load run
  const { data: run, error: runErr } = await supabase
    .from('ai_runs')
    .select('*')
    .eq('id', runId)
    .eq('user_id', userId)
    .single();

  if (runErr || !run) {
    return json({ error: 'RUN_NOT_FOUND' }, 404);
  }

  // 2) Load invocations
  const { data: invocs } = await supabase
    .from('ai_tool_invocations')
    .select('tool_key,args,result_summary,duration_ms,success,created_at')
    .eq('run_id', runId)
    .order('created_at', { ascending: true });

  const toolsInvoked = (invocs ?? []).map((row: any) => ({
    tool_key: row.tool_key,
    args_preview: maskPreview(row.args || {}),
    result_preview: maskPreview(row.result_summary || null),
    duration_ms: row.duration_ms ?? null,
    success: row.success ?? null,
    at: row.created_at,
  }));

  // 3) Last assistant message (optional)
  const { data: lastMsg } = await supabase
    .from('ai_messages')
    .select('content, created_at')
    .eq('run_id', runId)
    .eq('user_id', userId)
    .eq('role', 'assistant')
    .order('created_at', { ascending: false })
    .limit(1);

  const answer = lastMsg?.[0]?.content ?? run?.last_answer ?? null;

  // 4) Plan + actions from context
  const plan = run?.context?.plan ?? undefined;
  const actions = run?.actions ?? null;

  const stepsCompleted = (invocs ?? []).filter((r: any) => r.success === true).length;

  const response: StatusResponse = {
    run_id: runId,
    status: run.status,
    plan,
    steps_completed: stepsCompleted,
    tools_invoked: toolsInvoked,
    answer,
    actions,
    error: run?.error ? { code: 'AGENT_ERROR', message: run.error } : null,
  };

  return json(response, 200);
}

function json(obj: any, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
