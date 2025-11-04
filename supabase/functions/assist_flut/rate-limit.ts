import { ToolDefinition, ExecuteContext } from "./types.ts";

/**
 * Simple rate limit: count invocations in last minute from ai_tool_invocations
 */
export async function checkRateLimit(
  ctx: ExecuteContext,
  tool: ToolDefinition,
): Promise<{ allowed: boolean; retryAfterMs?: number }> {
  const limit = tool.rate_limit_per_min ?? 60;
  if (limit <= 0) return { allowed: true };

  const sinceIso = new Date(Date.now() - 60_000).toISOString();

  // Query simple pour compter les invocations
  const { data: rows, error } = await ctx.supabase
    .from('ai_tool_invocations')
    .select('id')
    .eq('user_id', ctx.userId)
    .eq('tool_key', tool.key)
    .gte('created_at', sinceIso);

  if (error) {
    // En cas d'erreur, laissons passer pour ne pas bloquer l'utilisateur
    return { allowed: true };
  }

  const n = rows?.length ?? 0;
  if (n >= limit) {
    return { allowed: false, retryAfterMs: 60_000 };
  }
  return { allowed: true };
}
