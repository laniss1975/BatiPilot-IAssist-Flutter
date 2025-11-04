/**
 * /assist/confirm endpoint
 *
 * Handles user confirmation (approve/deny) for Agent actions requiring approval.
 * Used in Review/dry-run mode.
 */

export async function handleConfirm(req: Request, supabase: any, userId: string) {
  const body = await req.json().catch(() => ({}));
  const { run_id, confirmation, comment } = body || {};

  if (!run_id || typeof confirmation !== 'boolean') {
    return json({ error: 'run_id and confirmation(boolean) required' }, 400);
  }

  // Load run
  const { data: run, error: runErr } = await supabase
    .from('ai_runs')
    .select('*')
    .eq('id', run_id)
    .eq('user_id', userId)
    .single();

  if (runErr || !run) {
    return json({ error: 'RUN_NOT_FOUND' }, 404);
  }

  // Build new context.confirmation
  const context = run.context || {};
  context.confirmation = {
    decided: true,
    approved: confirmation,
    comment: comment || null,
    decided_at: new Date().toISOString(),
  };

  // Target status
  let newStatus: string = confirmation ? 'executing' : 'cancelled';

  // Check expiration
  if (run.status === 'waiting_confirmation' && run.confirmation_expires_at) {
    if (new Date(run.confirmation_expires_at).getTime() < Date.now() && confirmation) {
      // Expired: refuse
      newStatus = 'expired';
      context.confirmation.expired = true;
    }
  }

  // Update run
  const { error: updErr } = await supabase
    .from('ai_runs')
    .update({ status: newStatus, context })
    .eq('id', run_id)
    .eq('user_id', userId);

  if (updErr) {
    return json({ error: 'UPDATE_FAILED', details: updErr.message }, 500);
  }

  // Note: If using SSE /stream mode, the client should reconnect to /stream?run_id=...
  // to resume execution. The Executor will see status='executing' and continue.

  return json({ success: true, run_id, status: newStatus }, 200);
}

function json(obj: any, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
