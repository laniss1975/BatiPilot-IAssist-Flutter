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
import type { ExecuteContext } from './types.ts';

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

  // TODO: Call LLM API (OpenAI, Gemini, etc.)
  // For now, return a mock plan for testing
  console.log('[Planner] Prompt:', prompt);

  // Log message
  await ctx.supabase.from('ai_messages').insert({
    run_id: ctx.runId,
    user_id: ctx.userId,
    role: 'user',
    content: maskPII(userMessage),
  });

  await ctx.supabase.from('ai_messages').insert({
    run_id: ctx.runId,
    user_id: ctx.userId,
    role: 'system',
    content: maskPII(prompt),
  });

  // TODO: Replace with real LLM call
  const mockPlan = {
    plan_id: 'plan_' + Date.now(),
    summary: 'Créer un client Jean Dupont',
    steps: [
      {
        id: 's1',
        type: 'tool',
        description: 'Créer le client Jean Dupont',
        tool_key: 'create_client',
        args: { nom: 'Dupont', prenom: 'Jean', email: 'jean@dupont.fr' },
        requires_confirmation: true,
        success_criteria: 'Client créé avec succès',
        on_error: 'ask_user',
      },
    ],
    questions_for_user: [],
    estimated_calls: { tools: 1, llm_rounds: 1 },
    stop_reasons: ['user_confirmation_required'],
  };

  return mockPlan;
}

/**
 * Execute plan with Tools + self-repair
 */
async function executePlan(
  plan: any,
  tools: any[],
  ctx: ExecuteContext,
  send: (event: string, data: any) => void
): Promise<void> {
  let iterations = 0;

  // Build initial messages for Executor
  const messages: any[] = [
    {
      role: 'system',
      content: getExecutorPrompt(plan, ctx.currentRoute || 'home', 'user', tools),
    },
  ];

  while (iterations++ < MAX_ITERATIONS) {
    // TODO: Call LLM with function calling
    // For now, simulate tool_calls from plan

    if (!plan.steps || plan.steps.length === 0) {
      break;
    }

    for (const step of plan.steps) {
      if (step.type !== 'tool' || !step.tool_key) {
        continue;
      }

      const tool = tools.find((t) => t.key === step.tool_key);
      if (!tool) {
        send(SSE_EVENTS.TOOL_CALL_FAILED, {
          run_id: ctx.runId,
          tool_key: step.tool_key,
          error: { code: 'TOOL_NOT_FOUND', message: `Tool ${step.tool_key} not found` },
        });
        continue;
      }

      // Check confirmation (already done in planner, but double-check)
      if (step.requires_confirmation) {
        // This shouldn't happen in executor phase (should be caught in planner)
        send(SSE_EVENTS.USER_CONFIRMATION_REQUESTED, {
          run_id: ctx.runId,
          step: step,
        });
        return;
      }

      // Self-repair loop
      let attempt = 0;
      let execOk = false;

      while (attempt++ <= MAX_SELF_REPAIR_ATTEMPTS && !execOk) {
        send(SSE_EVENTS.TOOL_CALL_STARTED, {
          run_id: ctx.runId,
          tool_key: tool.key,
          args_preview: maskPII(JSON.stringify(step.args)),
        });

        const exec = await executeTool(tool, step.args, ctx);

        if (exec.ok) {
          send(SSE_EVENTS.TOOL_CALL_SUCCEEDED, {
            run_id: ctx.runId,
            tool_key: tool.key,
            result_preview: maskPII(JSON.stringify(exec.result).substring(0, 200)),
          });

          messages.push({
            role: 'tool',
            tool_call_id: step.id,
            content: JSON.stringify(exec.result),
          });

          execOk = true;
        } else {
          send(SSE_EVENTS.TOOL_CALL_FAILED, {
            run_id: ctx.runId,
            tool_key: tool.key,
            error: exec.error,
            attempt: attempt,
            max_attempts: MAX_SELF_REPAIR_ATTEMPTS + 1,
          });

          messages.push({
            role: 'tool',
            tool_call_id: step.id,
            content: JSON.stringify({ tool_error: exec.error }),
          });

          if (attempt > MAX_SELF_REPAIR_ATTEMPTS) {
            messages.push({
              role: 'assistant',
              content: `Je n'ai pas pu exécuter ${tool.key} après ${MAX_SELF_REPAIR_ATTEMPTS + 1} tentatives (erreur: ${exec.error.code}). Voulez-vous corriger ou annuler ?`,
            });

            send(SSE_EVENTS.ANSWER_FINAL, {
              run_id: ctx.runId,
              answer: `Erreur lors de l'exécution de ${tool.key}: ${exec.error.message}`,
              stop_reason: 'execution_error',
            });

            return;
          }
        }
      }
    }

    // After executing all steps, send final answer
    send(SSE_EVENTS.ANSWER_FINAL, {
      run_id: ctx.runId,
      answer: 'Plan exécuté avec succès.',
      tools_used: plan.steps.map((s: any) => s.tool_key).filter(Boolean),
      stop_reason: 'done',
    });

    return;
  }

  // Max iterations reached
  send(SSE_EVENTS.AGENT_ERROR, {
    run_id: ctx.runId,
    error: {
      code: 'MAX_ITERATIONS',
      message: `Max iterations (${MAX_ITERATIONS}) atteintes`,
    },
  });
}
