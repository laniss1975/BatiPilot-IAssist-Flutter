/**
 * LLM Provider Integration
 * Supports: OpenAI, Google Gemini, Anthropic Claude
 */

export type LLMProvider = 'openai' | 'gemini' | 'claude';

export type LLMMessage = {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string;
  tool_call_id?: string;
  tool_calls?: any[];
};

export type LLMToolCall = {
  id: string;
  type: 'function';
  function: {
    name: string;
    arguments: string; // JSON string
  };
};

export type LLMResponse = {
  content: string;
  tool_calls?: LLMToolCall[];
  stop_reason: 'stop' | 'tool_calls' | 'max_tokens' | 'error';
  usage?: {
    input_tokens: number;
    output_tokens: number;
  };
};

export type LLMConfig = {
  provider: LLMProvider;
  model?: string;
  api_key: string;
  temperature?: number;
  max_tokens?: number;
};

/**
 * Call LLM with unified interface
 */
export async function callLLM(
  messages: LLMMessage[],
  tools: any[],
  config: LLMConfig
): Promise<LLMResponse> {
  switch (config.provider) {
    case 'openai':
      return callOpenAI(messages, tools, config);
    case 'gemini':
      return callGemini(messages, tools, config);
    case 'claude':
      return callClaude(messages, tools, config);
    default:
      throw new Error(`Unsupported provider: ${config.provider}`);
  }
}

/**
 * OpenAI API call
 */
async function callOpenAI(
  messages: LLMMessage[],
  tools: any[],
  config: LLMConfig
): Promise<LLMResponse> {
  const model = config.model || 'gpt-4o-mini';

  const payload: any = {
    model,
    messages: messages.map((m) => ({
      role: m.role,
      content: m.content,
      tool_call_id: m.tool_call_id,
      tool_calls: m.tool_calls,
    })),
    temperature: config.temperature ?? 0.7,
    max_tokens: config.max_tokens ?? 4000,
  };

  if (tools.length > 0) {
    payload.tools = tools.map((t) => ({
      type: 'function',
      function: {
        name: t.key,
        description: t.description,
        parameters: t.parameters_schema,
      },
    }));
    payload.tool_choice = 'auto';
  }

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${config.api_key}`,
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`OpenAI API error (${response.status}): ${error}`);
  }

  const data = await response.json();
  const choice = data.choices?.[0];

  if (!choice) {
    throw new Error('No choice returned from OpenAI');
  }

  return {
    content: choice.message?.content || '',
    tool_calls: choice.message?.tool_calls?.map((tc: any) => ({
      id: tc.id,
      type: 'function',
      function: {
        name: tc.function.name,
        arguments: tc.function.arguments,
      },
    })),
    stop_reason: choice.finish_reason === 'tool_calls' ? 'tool_calls' : 'stop',
    usage: {
      input_tokens: data.usage?.prompt_tokens || 0,
      output_tokens: data.usage?.completion_tokens || 0,
    },
  };
}

/**
 * Google Gemini API call
 */
async function callGemini(
  messages: LLMMessage[],
  tools: any[],
  config: LLMConfig
): Promise<LLMResponse> {
  const model = config.model || 'gemini-1.5-flash';

  // Convert messages to Gemini format
  const contents: any[] = [];
  let systemInstruction = '';

  for (const msg of messages) {
    if (msg.role === 'system') {
      systemInstruction = msg.content;
    } else if (msg.role === 'user') {
      contents.push({
        role: 'user',
        parts: [{ text: msg.content }],
      });
    } else if (msg.role === 'assistant') {
      contents.push({
        role: 'model',
        parts: [{ text: msg.content }],
      });
    } else if (msg.role === 'tool') {
      // Gemini uses function responses
      contents.push({
        role: 'function',
        parts: [{
          functionResponse: {
            name: msg.tool_call_id || 'unknown',
            response: JSON.parse(msg.content),
          },
        }],
      });
    }
  }

  const payload: any = {
    contents,
    systemInstruction: systemInstruction ? { parts: [{ text: systemInstruction }] } : undefined,
    generationConfig: {
      temperature: config.temperature ?? 0.7,
      maxOutputTokens: config.max_tokens ?? 4000,
    },
  };

  if (tools.length > 0) {
    payload.tools = [{
      functionDeclarations: tools.map((t) => ({
        name: t.key,
        description: t.description,
        parameters: t.parameters_schema,
      })),
    }];
  }

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${config.api_key}`;

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Gemini API error (${response.status}): ${error}`);
  }

  const data = await response.json();
  const candidate = data.candidates?.[0];

  if (!candidate) {
    throw new Error('No candidate returned from Gemini');
  }

  // Extract text and function calls
  let content = '';
  const toolCalls: LLMToolCall[] = [];

  for (const part of candidate.content?.parts || []) {
    if (part.text) {
      content += part.text;
    }
    if (part.functionCall) {
      toolCalls.push({
        id: `call_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`,
        type: 'function',
        function: {
          name: part.functionCall.name,
          arguments: JSON.stringify(part.functionCall.args || {}),
        },
      });
    }
  }

  return {
    content,
    tool_calls: toolCalls.length > 0 ? toolCalls : undefined,
    stop_reason: toolCalls.length > 0 ? 'tool_calls' : 'stop',
    usage: {
      input_tokens: data.usageMetadata?.promptTokenCount || 0,
      output_tokens: data.usageMetadata?.candidatesTokenCount || 0,
    },
  };
}

/**
 * Anthropic Claude API call
 */
async function callClaude(
  messages: LLMMessage[],
  tools: any[],
  config: LLMConfig
): Promise<LLMResponse> {
  const model = config.model || 'claude-3-5-sonnet-20241022';

  // Extract system message
  const systemMessage = messages.find((m) => m.role === 'system')?.content || '';
  const filteredMessages = messages.filter((m) => m.role !== 'system');

  // Convert to Claude format
  const claudeMessages = filteredMessages.map((m) => {
    if (m.role === 'tool') {
      return {
        role: 'user',
        content: [{
          type: 'tool_result',
          tool_use_id: m.tool_call_id || 'unknown',
          content: m.content,
        }],
      };
    }
    return {
      role: m.role === 'assistant' ? 'assistant' : 'user',
      content: m.content,
    };
  });

  const payload: any = {
    model,
    messages: claudeMessages,
    system: systemMessage,
    max_tokens: config.max_tokens ?? 4000,
    temperature: config.temperature ?? 0.7,
  };

  if (tools.length > 0) {
    payload.tools = tools.map((t) => ({
      name: t.key,
      description: t.description,
      input_schema: t.parameters_schema,
    }));
  }

  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': config.api_key,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Claude API error (${response.status}): ${error}`);
  }

  const data = await response.json();

  // Extract text and tool calls
  let content = '';
  const toolCalls: LLMToolCall[] = [];

  for (const block of data.content || []) {
    if (block.type === 'text') {
      content += block.text;
    }
    if (block.type === 'tool_use') {
      toolCalls.push({
        id: block.id,
        type: 'function',
        function: {
          name: block.name,
          arguments: JSON.stringify(block.input || {}),
        },
      });
    }
  }

  return {
    content,
    tool_calls: toolCalls.length > 0 ? toolCalls : undefined,
    stop_reason: data.stop_reason === 'tool_use' ? 'tool_calls' : 'stop',
    usage: {
      input_tokens: data.usage?.input_tokens || 0,
      output_tokens: data.usage?.output_tokens || 0,
    },
  };
}

/**
 * Get LLM config from USER database configuration (ai_provider_configs + user_api_keys)
 * This is the PRIMARY method that respects user's model selection in the app
 */
export async function getUserLLMConfig(
  supabase: any,
  userId: string,
  authHeader: string
): Promise<LLMConfig> {
  console.log('[getUserLLMConfig] Starting - userId:', userId);

  // 1. Load active model configuration from ai_provider_configs
  const { data: configData, error: configError } = await supabase
    .from('ai_provider_configs')
    .select('provider_name, model_name')
    .eq('user_id', userId)
    .eq('module_name', 'global')
    .eq('is_active', true)
    .maybeSingle();

  console.log('[getUserLLMConfig] Config query result:', { configData, configError });

  if (configError) {
    console.error('[getUserLLMConfig] Config error:', configError);
    throw new Error(`Failed to load user model config: ${configError.message}`);
  }

  if (!configData) {
    console.error('[getUserLLMConfig] No active config found for user:', userId);
    throw new Error('No active model configuration found. Please configure a model in Settings > AI Control Center.');
  }

  const providerName = configData.provider_name;
  const modelName = configData.model_name;
  console.log('[getUserLLMConfig] Using provider:', providerName, 'model:', modelName);

  // 2. Load provider details from ai_providers
  const { data: providerDetails, error: providerError } = await supabase
    .from('ai_providers')
    .select('provider_key, api_endpoint, api_auth_method, api_headers')
    .eq('provider_key', providerName)
    .single();

  console.log('[getUserLLMConfig] Provider query result:', { providerDetails, providerError });

  if (providerError) {
    console.error('[getUserLLMConfig] Provider error:', providerError);
    throw new Error(`Failed to load provider details: ${providerError.message}`);
  }

  if (!providerDetails) {
    console.error('[getUserLLMConfig] Provider not found:', providerName);
    throw new Error(`Provider ${providerName} not found in ai_providers table.`);
  }

  // 3. Get user's API key via ai-keys-manager edge function
  const keysManagerUrl = `${Deno.env.get('SUPABASE_URL')!}/functions/v1/ai-keys-manager`;
  console.log('[getUserLLMConfig] Calling ai-keys-manager at:', keysManagerUrl);

  const keyResponse = await fetch(keysManagerUrl, {
    method: 'POST',
    headers: {
      'Authorization': authHeader,
      'x-internal-token': Deno.env.get('EDGE_FUNCTIONS_SECRET') || '',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      action: 'get-key',
      provider: providerDetails.provider_key,
    }),
  });

  console.log('[getUserLLMConfig] ai-keys-manager response status:', keyResponse.status);

  if (!keyResponse.ok) {
    const errorBody = await keyResponse.json().catch(() => ({ error: 'Unknown error' }));
    console.error('[getUserLLMConfig] ai-keys-manager error:', errorBody);
    throw new Error(`Failed to get API key: ${errorBody.error || keyResponse.statusText}`);
  }

  const keyData = await keyResponse.json();
  console.log('[getUserLLMConfig] API key retrieved successfully:', { hasKey: !!keyData.apiKey, success: keyData.success });

  if (!keyData.success || !keyData.apiKey) {
    console.error('[getUserLLMConfig] No valid API key returned');
    throw new Error(`API key not found for provider ${providerName}. Please add an API key in Settings.`);
  }

  // Map provider_key to LLMProvider type
  let provider: LLMProvider;
  switch (providerDetails.provider_key) {
    case 'openai':
      provider = 'openai';
      break;
    case 'google':
    case 'gemini':
      provider = 'gemini';
      break;
    case 'anthropic':
    case 'claude':
      provider = 'claude';
      break;
    default:
      console.error('[getUserLLMConfig] Unsupported provider:', providerDetails.provider_key);
      throw new Error(`Unsupported provider: ${providerDetails.provider_key}`);
  }

  console.log('[getUserLLMConfig] Success! Returning config for:', provider, modelName);

  return {
    provider,
    model: modelName,
    api_key: keyData.apiKey,
    temperature: 0.7,
    max_tokens: 4000,
  };
}

/**
 * Get LLM config from environment variables (FALLBACK only - for admin/testing)
 * NOTE: This should NOT be used for normal user requests
 */
export function getLLMConfigFromEnv(provider?: LLMProvider, model?: string): LLMConfig {
  const effectiveProvider = provider || (Deno.env.get('DEFAULT_LLM_PROVIDER') as LLMProvider) || 'openai';

  let api_key = '';

  switch (effectiveProvider) {
    case 'openai':
      api_key = Deno.env.get('OPENAI_API_KEY') || '';
      break;
    case 'gemini':
      api_key = Deno.env.get('GEMINI_API_KEY') || '';
      break;
    case 'claude':
      api_key = Deno.env.get('ANTHROPIC_API_KEY') || '';
      break;
  }

  if (!api_key) {
    throw new Error(`Missing API key for provider: ${effectiveProvider}`);
  }

  return {
    provider: effectiveProvider,
    model,
    api_key,
    temperature: parseFloat(Deno.env.get('LLM_TEMPERATURE') || '0.7'),
    max_tokens: parseInt(Deno.env.get('LLM_MAX_TOKENS') || '4000', 10),
  };
}
