import { ajv } from "./ajv.ts";
import { checkRateLimit } from "./rate-limit.ts";
import { withTimeout, maskPII } from "./utils.ts";
import { ToolDefinition, ExecuteContext, ExecuteResult } from "./types.ts";
import { deriveIdempotencyKey } from "./deriveIdempotencyKey.ts";

// Validateur cache par tool.key
const validators = new Map<string, any>();
const returnValidators = new Map<string, any>();

function getValidator(tool: ToolDefinition) {
  if (!validators.has(tool.key)) {
    const validate = ajv.compile(tool.parameters_schema);
    validators.set(tool.key, validate);
  }
  return validators.get(tool.key);
}

function getReturnValidator(tool: ToolDefinition) {
  if (!tool.returns_schema) return null;
  const key = tool.key + "::returns";
  if (!returnValidators.has(key)) {
    const validate = ajv.compile(tool.returns_schema);
    returnValidators.set(key, validate);
  }
  return returnValidators.get(key);
}

// Enregistre une invocation (succès/échec)
async function logInvocation(ctx: ExecuteContext, tool: ToolDefinition, args: any, result: any, success: boolean, error?: { code: string; message: string }) {
  const summary = success ? result : { error_code: error?.code, error_message: error?.message };
  await ctx.supabase.from('ai_tool_invocations').insert({
    run_id: ctx.runId,
    user_id: ctx.userId,
    tool_key: tool.key,
    args,
    result_summary: summary,
    duration_ms: null, // à compléter si vous mesurez précisément
    success,
    error_code: error?.code ?? null,
    error_message: error?.message ?? null
  });
}

export async function executeTool(
  tool: ToolDefinition,
  rawArgs: any,
  ctx: ExecuteContext
): Promise<ExecuteResult> {
  // 0) Tool enabled?
  if (!tool.enabled) {
    return { ok: false, error: { code: 'TOOL_DISABLED', message: `Tool ${tool.key} is disabled.` } };
  }

  // 1) Validation paramètres
  const validate = getValidator(tool);
  const valid = validate(rawArgs);
  if (!valid) {
    const details = validate.errors;
    await logInvocation(ctx, tool, rawArgs, null, false, { code: 'VALIDATION_ERROR', message: JSON.stringify(details) });
    return { ok: false, error: { code: 'VALIDATION_ERROR', message: 'Invalid arguments', details } };
  }
  const args = rawArgs; // déjà validés

  // 2) Rate limiting
  const rl = await checkRateLimit(ctx, tool);
  if (!rl.allowed) {
    await logInvocation(ctx, tool, args, null, false, { code: 'RATE_LIMIT', message: 'Rate limit exceeded' });
    return { ok: false, error: { code: 'RATE_LIMIT', message: `Too many calls to ${tool.key}. Retry later.` } };
  }

  // 3) Timeout wrapper
  const timeoutMs = Math.max(1000, tool.timeout_ms || 10000);

  try {
    let result: any = null;
    switch (tool.execution_type) {
      case 'supabase_rpc': {
        const fn = tool.execution_config?.function;
        const schema = tool.execution_config?.schema ?? 'public';
        if (!fn) {
          throw new Error('RPC function not specified');
        }

        // Idempotency: auto-derive key if configured
        if (tool.idempotency?.key_field && Array.isArray(tool.idempotency?.derive_from)) {
          const key = await deriveIdempotencyKey(
            tool.key,
            ctx.userId,
            args,
            tool.idempotency.derive_from
          );
          if (!args[tool.idempotency.key_field]) {
            args[tool.idempotency.key_field] = key;
          }
        }

        // Appel RPC
        const rpcResult = await withTimeout(
          ctx.supabase.rpc(fn, args),
          timeoutMs,
          ctx.signal
        );
        if (rpcResult?.error) throw new Error(rpcResult.error.message || 'RPC error');
        result = rpcResult.data ?? { success: true };
        break;
      }

      case 'supabase_query': {
        // ex execution_config:
        // { table: "clients", operation: "select", columns: ["id","nom"], allowed_filters: [{"field":"nom","ops":["eq","ilike"]}], default_limit:50, max_limit:100 }
        const ec = tool.execution_config || {};
        const table = ec.table;
        const operation = ec.operation || 'select';
        const columns = (ec.columns && Array.isArray(ec.columns)) ? ec.columns : ['*'];
        const allowedFilters = ec.allowed_filters || []; // [{field, ops:[]}]
        const defaultLimit = ec.default_limit ?? 50;
        const maxLimit = ec.max_limit ?? 100;

        if (!table || operation !== 'select') {
          throw new Error('Only select is supported in v1');
        }

        let q = ctx.supabase.from(table).select(columns.join(','));

        // Filters sécurisés (args.filters: [{field, op, value}])
        if (Array.isArray(args?.filters)) {
          for (const f of args.filters) {
            const spec = allowedFilters.find((af: any) => af.field === f.field && af.ops?.includes(f.op));
            if (!spec) {
              throw new Error(`Filter not allowed: ${f.field}:${f.op}`);
            }
            // Appliquer opérateur autorisé
            switch (f.op) {
              case 'eq': q = q.eq(f.field, f.value); break;
              case 'ilike': q = q.ilike(f.field, f.value); break;
              case 'gt': q = q.gt(f.field, f.value); break;
              case 'gte': q = q.gte(f.field, f.value); break;
              case 'lt': q = q.lt(f.field, f.value); break;
              case 'lte': q = q.lte(f.field, f.value); break;
              case 'in': q = q.in(f.field, Array.isArray(f.value) ? f.value : [f.value]); break;
              default: throw new Error(`Op not implemented: ${f.op}`);
            }
          }
        }

        // orderBy
        if (args?.order_by?.field) {
          const field = args.order_by.field;
          const dir = (args.order_by.direction || 'asc').toLowerCase() === 'desc' ? false : true;
          // Optionnel: whitelister fields d'ordre dans execution_config.allowed_order
          q = q.order(field, { ascending: dir });
        }

        const limit = Math.min(Math.max(1, args?.limit ?? defaultLimit), maxLimit);
        const { data, error } = await withTimeout(q.limit(limit), timeoutMs, ctx.signal);
        if (error) throw new Error(error.message || 'Query error');
        result = data ?? [];
        break;
      }

      case 'flutter_action': {
        // Ne pas exécuter côté serveur: on renvoie une action à l'UI
        result = { action: tool.execution_config?.action_type, payload: args };
        break;
      }

      case 'storage': {
        // execution_config: { action: 'upload'|'get_url', bucket: 'devis', path_template: 'devis/{{project_id}}/{{filename}}' }
        const ec = tool.execution_config || {};
        const bucket = ec.bucket;
        if (!bucket) throw new Error('Storage bucket required');

        if (ec.action === 'upload') {
          // args: { file_base64, path }
          if (!args?.file_base64 || !args?.path) throw new Error('file_base64 and path required');
          const binary = Uint8Array.from(atob(args.file_base64), c => c.charCodeAt(0));
          const { data, error } = await withTimeout(
            ctx.supabase.storage.from(bucket).upload(args.path, binary, { upsert: true, contentType: args?.content_type || 'application/octet-stream' }),
            timeoutMs,
            ctx.signal
          );
          if (error) throw new Error(error.message);
          result = { success: true, path: data?.path };
        } else if (ec.action === 'get_url') {
          // args: { path }
          const { data } = ctx.supabase.storage.from(bucket).getPublicUrl(args.path);
          result = { url: data?.publicUrl };
        } else {
          throw new Error('Unsupported storage action');
        }
        break;
      }

      case 'http_request': {
        // V2: vérifier whitelist ai_http_hosts_allowed + méthode + headers
        throw new Error('http_request not implemented in v1');
      }

      case 'composed': {
        // V2: exécuter steps séquentiellement, propager outputs, et rollback partiel si besoin
        throw new Error('composed not implemented in v1');
      }

      default:
        throw new Error(`Unknown execution_type: ${tool.execution_type}`);
    }

    // 4) Validation du retour si returns_schema défini
    const rVal = getReturnValidator(tool);
    if (rVal) {
      const ok = rVal(result);
      if (!ok) {
        // On loggue mais on renvoie tout de même au LLM pour tentative de réparation
        await logInvocation(ctx, tool, args, { validation_errors: rVal.errors, raw: result }, true);
        return { ok: true, result: { warning: 'RETURN_VALIDATION_FAILED', validation_errors: rVal.errors, raw: result } };
      }
    }

    await logInvocation(ctx, tool, args, result, true);
    return { ok: true, result };

  } catch (e: any) {
    const msg = (e?.message || 'UNKNOWN_ERROR');
    await logInvocation(ctx, tool, args, null, false, { code: 'EXECUTION_ERROR', message: msg });
    return { ok: false, error: { code: msg === 'TIMEOUT' ? 'TIMEOUT' : 'EXECUTION_ERROR', message: msg } };
  }
}
