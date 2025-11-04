export type ExecutionType =
  | 'supabase_rpc'
  | 'supabase_query'
  | 'flutter_action'
  | 'storage'
  | 'http_request'
  | 'composed';

export type ToolDefinition = {
  id: string;
  key: string;
  name: string;
  description: string;
  category?: string;
  version?: string;
  risk_level: 'low'|'medium'|'high'|'critical';
  confirmation_policy: 'none'|'required'|'required_strong';
  roles_allowed?: string[] | null;

  parameters_schema: any;
  returns_schema?: any | null;

  execution_type: ExecutionType;
  execution_config: any;
  timeout_ms: number;
  rate_limit_per_min?: number | null;
  idempotency?: { key_field?: string } | null;
  side_effects?: boolean;
  streaming_supported?: boolean;

  enabled: boolean;
  enabled_from_routes?: string[] | null;
  depends_on?: string[] | null;
  tags?: string[] | null;

  visibility: 'system'|'user';
  user_id?: string | null;
  is_system: boolean;
};

export type ExecuteContext = {
  supabase: any;
  userId: string;
  runId: string;
  traceId?: string;
  currentRoute?: string;
  signal?: AbortSignal;
};

export type ExecuteResult =
  | { ok: true; result: any; actions?: any[] }
  | { ok: false; error: { code: string; message: string; details?: any } };
