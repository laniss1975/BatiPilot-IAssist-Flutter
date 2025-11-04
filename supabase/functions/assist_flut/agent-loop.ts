/**
 * Agent Loop - Main orchestration
 *
 * Architecture: Planner → Confirmation → Executor
 * - Planner: Generates execution plan
 * - Confirmation: User validates plan (if required)
 * - Executor: Executes plan with Tools + self-repair
 */

import { createSSEStream, SSE_EVENTS } from './sse.ts';
import { loadToolsForRoute } from './tools-loader.ts';
import { executeTool } from './executeTool.ts';
import { getPlannerPrompt, getExecutorPrompt, buildToolsSubsetDoc, formatToolsForProvider } from './prompts.ts';
import { maskPII } from './utils.ts';
import { callLLM, getLLMConfig } from './llm.ts';
import type { ExecuteContext } from './types.ts';
import type { LLMMessage } from './llm.ts';

const MAX_ITERATIONS = 5;
const MAX_SELF_REPAIR_ATTEMPTS = 2;

export async function agentLoop(
  userMessage: string,
  ctx: ExecuteContext,
  dryRun: boolean = true
) {
  // Create SSE stream
  const { stream, send, close } = createSSEStream();

  // Start async processing
  (async () => {
    try {
      // 1. Load Tools (with route gating)
      const tools = await loadToolsForRoute(ctx.supabase, ctx.userId, ctx.currentRoute);

      // 2. Create run record
      const { data: run, error: runError } = await ctx.supabase
        .from('ai_runs')
        .insert({
          user_id: ctx.userId,
          route: ctx.currentRoute,
          model: 'gpt-4o-mini', // TODO: Get from config
          status: 'planning',
          trace_id: ctx.traceId,
        })
        .select()
        .single();

      if (runError || !run) {
        throw new Error(`Failed to create run: ${runError?.message}`);
      }

      ctx.runId = run.id;

      // Emit agent_started
      send(SSE_EVENTS.AGENT_STARTED, {
        run_id: run.id,
        route: ctx.currentRoute,
        tools_count: tools.length,
      });

      // 3. PHASE 1: Planning
      const plan = await callPlanner(userMessage, tools, ctx, send);

      if (!plan) {
        throw new Error('Planning failed');
      }

      // Emit plan_ready
      send(SSE_EVENTS.PLAN_READY, {
        run_id: run.id,
        plan: {
          plan_id: plan.plan_id,
          summary: plan.summary,
          steps_count: plan.steps?.length || 0,
          estimated_calls: plan.estimated_calls,
        },
      });

      // Update run with plan
      await ctx.supabase
        .from('ai_runs')
        .update({ context: { plan }, status: 'planned' })
        .eq('id', run.id);

      // 4. Check if confirmation required
      const requiresConfirmation =
        dryRun ||
        plan.stop_reasons?.includes('user_confirmation_required') ||
        plan.steps?.some((s: any) => s.requires_confirmation);

      if (requiresConfirmation) {
        // Emit confirmation request
        send(SSE_EVENTS.USER_CONFIRMATION_REQUESTED, {
          run_id: run.id,
          plan: {
            plan_id: plan.plan_id,
            summary: plan.summary,
            steps: plan.steps?.map((s: any) => ({
              id: s.id,
              description: s.description,
              tool_key: s.tool_key,
              requires_confirmation: s.requires_confirmation,
            })),
          },
          requires_action: 'confirm',
        });

        // Update run status
        await ctx.supabase
          .from('ai_runs')
          .update({ status: 'waiting_confirmation' })
          .eq('id', run.id);

        // Emit agent_finished (waiting)
        send(SSE_EVENTS.AGENT_FINISHED, {
          run_id: run.id,
          status: 'waiting_confirmation',
          message: 'En attente de confirmation utilisateur',
        });

        close();
        return;
      }

      // 5. PHASE 2: Execution (if no confirmation needed OR already confirmed)
      await executePlugin(plan, tools, ctx, send);

      // 6. Finalize
      await ctx.supabase
        .from('ai_runs')
        .update({ status: 'succeeded' })
        .eq('id', run.id);

      send(SSE_EVENTS.AGENT_FINISHED, {
        run_id: run.id,
        status: 'succeeded',
      });

      close();
    } catch (error: any) {
      console.error('[agent-loop] Error:', error);

      send(SSE_EVENTS.AGENT_ERROR, {
        run_id: ctx.runId,
        error: {
          code: 'AGENT_ERROR',
          message: error.message,
        },
      });

      if (ctx.runId) {
        await ctx.supabase
          .from('ai_runs')
          .update({
            status: 'failed',
            error: error.message,
          })
          .eq('id', ctx.runId);
      }

      close();
    }
  })();

  return stream;
}

/**
 * Call Planner LLM to generate execution plan
 */
async function callPlanner(
  userMessage: string,
  tools: any[],
  ctx: ExecuteContext,
  send: (event: string, data: any) => void
): Promise<any> {
  const toolsDoc = buildToolsSubsetDoc(tools);
  const prompt = getPlannerPrompt(userMessage, ctx.currentRoute || 'home', 'user', toolsDoc);

  // Log user message
  await ctx.supabase.from('ai_messages').insert({
    run_id: ctx.runId,
    user_id: ctx.userId,
    role: 'user',
    content: maskPII(userMessage),
  });

  // Log system prompt
  await ctx.supabase.from('ai_messages').insert({
    run_id: ctx.runId,
    user_id: ctx.userId,
    role: 'system',
    content: maskPII(prompt),
  });

  // Build messages for Planner
  const messages: LLMMessage[] = [
    { role: 'system', content: prompt },
    { role: 'user', content: userMessage },
  ];

  // Get LLM config
  const llmConfig = getLLMConfig();

  // Call LLM (no tools for Planner, pure JSON response)
  const response = await callLLM(messages, [], llmConfig);

  // Log assistant response
  await ctx.supabase.from('ai_messages').insert({
    run_id: ctx.runId,
    user_id: ctx.userId,
    role: 'assistant',
    content: maskPII(response.content),
  });

  // Update run tokens
  await ctx.supabase.from('ai_runs').update({
    tokens_in: (ctx.tokensIn || 0) + (response.usage?.input_tokens || 0),
    tokens_out: (ctx.tokensOut || 0) + (response.usage?.output_tokens || 0),
  }).eq('id', ctx.runId);

  // Parse JSON response
  let plan: any;
  try {
    // Extract JSON from markdown code blocks if present
    let jsonStr = response.content.trim();
    const jsonMatch = jsonStr.match(/```json\n([\s\S]*?)\n```/);
    if (jsonMatch) {
      jsonStr = jsonMatch[1];
    }
    plan = JSON.parse(jsonStr);
  } catch (error: any) {
    console.error('[Planner] Failed to parse JSON:', error.message);
    throw new Error(`Planner returned invalid JSON: ${error.message}`);
  }

  // Validate plan structure
  if (!plan.summary || !Array.isArray(plan.steps)) {
    throw new Error('Invalid plan structure (missing summary or steps)');
  }

  // Add plan_id if missing
  if (!plan.plan_id) {
    plan.plan_id = 'plan_' + Date.now();
  }

  return plan;
}

/**
 * Execute plan with Tools + self-repair (with LLM function calling)
 */
async function executePlan(
  plan: any,
  tools: any[],
  ctx: ExecuteContext,
  send: (event: string, data: any) => void
): Promise<void> {
  let iterations = 0;

  // Build initial messages for Executor
  const messages: LLMMessage[] = [
    {
      role: 'system',
      content: getExecutorPrompt(plan, ctx.currentRoute || 'home', 'user', tools),
    },
    {
      role: 'user',
      content: `Exécute le plan suivant:\n\n${JSON.stringify(plan, null, 2)}`,
    },
  ];

  // Get LLM config
  const llmConfig = getLLMConfig();

  while (iterations++ < MAX_ITERATIONS) {
    // Call LLM with function calling
    const response = await callLLM(messages, tools, llmConfig);

    // Update tokens
    await ctx.supabase.from('ai_runs').update({
      tokens_in: (ctx.tokensIn || 0) + (response.usage?.input_tokens || 0),
      tokens_out: (ctx.tokensOut || 0) + (response.usage?.output_tokens || 0),
      iterations: iterations,
    }).eq('id', ctx.runId);

    // If no tool_calls, the LLM is done
    if (!response.tool_calls || response.tool_calls.length === 0) {
      // Final answer
      send(SSE_EVENTS.ANSWER_FINAL, {
        run_id: ctx.runId,
        answer: response.content,
        stop_reason: 'done',
      });

      await ctx.supabase.from('ai_messages').insert({
        run_id: ctx.runId,
        user_id: ctx.userId,
        role: 'assistant',
        content: maskPII(response.content),
      });

      return;
    }

    // Add assistant message with tool_calls
    messages.push({
      role: 'assistant',
      content: response.content || '',
      tool_calls: response.tool_calls,
    });

    await ctx.supabase.from('ai_messages').insert({
      run_id: ctx.runId,
      user_id: ctx.userId,
      role: 'assistant',
      content: maskPII(response.content || `[${response.tool_calls.length} tool call(s)]`),
    });

    // Execute each tool call
    for (const toolCall of response.tool_calls) {
      const toolKey = toolCall.function.name;
      const tool = tools.find((t) => t.key === toolKey);

      if (!tool) {
        send(SSE_EVENTS.TOOL_CALL_FAILED, {
          run_id: ctx.runId,
          tool_key: toolKey,
          error: { code: 'TOOL_NOT_FOUND', message: `Tool ${toolKey} not found` },
        });

        // Add error to messages
        messages.push({
          role: 'tool',
          tool_call_id: toolCall.id,
          content: JSON.stringify({ error: 'TOOL_NOT_FOUND', message: `Tool ${toolKey} not found` }),
        });
        continue;
      }

      // Parse args
      let args: any;
      try {
        args = JSON.parse(toolCall.function.arguments);
      } catch (error: any) {
        send(SSE_EVENTS.TOOL_CALL_FAILED, {
          run_id: ctx.runId,
          tool_key: toolKey,
          error: { code: 'INVALID_ARGS', message: `Invalid JSON arguments: ${error.message}` },
        });

        messages.push({
          role: 'tool',
          tool_call_id: toolCall.id,
          content: JSON.stringify({ error: 'INVALID_ARGS', message: error.message }),
        });
        continue;
      }

      // Execute tool (with self-repair handled internally)
      send(SSE_EVENTS.TOOL_CALL_STARTED, {
        run_id: ctx.runId,
        tool_key: toolKey,
        args_preview: maskPII(JSON.stringify(args).substring(0, 200)),
      });

      const exec = await executeTool(tool, args, ctx);

      if (exec.ok) {
        send(SSE_EVENTS.TOOL_CALL_SUCCEEDED, {
          run_id: ctx.runId,
          tool_key: toolKey,
          result_preview: maskPII(JSON.stringify(exec.result).substring(0, 200)),
        });

        messages.push({
          role: 'tool',
          tool_call_id: toolCall.id,
          content: JSON.stringify(exec.result),
        });

        await ctx.supabase.from('ai_messages').insert({
          run_id: ctx.runId,
          user_id: ctx.userId,
          role: 'tool',
          content: maskPII(`Tool ${toolKey} succeeded: ${JSON.stringify(exec.result).substring(0, 200)}...`),
        });
      } else {
        send(SSE_EVENTS.TOOL_CALL_FAILED, {
          run_id: ctx.runId,
          tool_key: toolKey,
          error: exec.error,
        });

        messages.push({
          role: 'tool',
          tool_call_id: toolCall.id,
          content: JSON.stringify({ error: exec.error }),
        });

        await ctx.supabase.from('ai_messages').insert({
          run_id: ctx.runId,
          user_id: ctx.userId,
          role: 'tool',
          content: maskPII(`Tool ${toolKey} failed: ${JSON.stringify(exec.error)}`),
        });
      }
    }

    // Continue loop to let LLM process tool results and decide next action
  }

  // Max iterations reached
  send(SSE_EVENTS.AGENT_ERROR, {
    run_id: ctx.runId,
    error: {
      code: 'MAX_ITERATIONS',
      message: `Max iterations (${MAX_ITERATIONS}) atteintes`,
    },
  });

  send(SSE_EVENTS.ANSWER_FINAL, {
    run_id: ctx.runId,
    answer: 'Désolé, j\'ai atteint le nombre maximum d\'itérations sans terminer la tâche.',
    stop_reason: 'max_iterations',
  });
}
