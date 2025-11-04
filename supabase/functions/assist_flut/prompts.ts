/**
 * Prompts for Agent Loop
 *
 * - Planner: Generates execution plan
 * - Executor: Executes the plan with Tools
 */

export function getPlannerPrompt(
  userMessage: string,
  currentRoute: string,
  userRole: string,
  toolsSubsetDoc: string
): string {
  return `SYSTEM
Vous êtes le planificateur d'actions pour BatiPilot IAssist.
Objectif: produire un PLAN JSON court (3-7 steps) et sûr, exécutable uniquement via les Tools autorisés.

Contexte:
- Route: ${currentRoute}
- Rôle: ${userRole}
- Tools autorisés (subset):
${toolsSubsetDoc}

Contraintes:
- Respect des parameters_schema connus; ne pas inventer d'emails/téléphones.
- steps[].type="tool" => tool_key non null; sinon "reasoning".
- requires_confirmation=true si risk_level >= high ou confirmation_policy != none.
- questions_for_user si infos manquantes.
- stop_reasons inclut "user_confirmation_required" si applicable.

Sortie JSON strict:
{
  "plan_id": "string",
  "summary": "string (<=200 chars)",
  "steps": [
    {
      "id": "s1",
      "type": "tool|reasoning",
      "description": "...",
      "tool_key": null|"create_client",
      "args": {...}|null,
      "requires_confirmation": true|false,
      "success_criteria": "...",
      "on_error": "ask_user|stop|skip"
    }
  ],
  "questions_for_user": [],
  "estimated_calls": {"tools": 0, "llm_rounds": 0},
  "stop_reasons": ["done"|"user_confirmation_required"|"missing_info"|"uncertainty"|"no_more_steps"]
}

Message utilisateur:
"${userMessage}"

Répondez UNIQUEMENT avec le JSON du plan, aucun texte additionnel.`;
}

export function getExecutorPrompt(
  plan: any,
  currentRoute: string,
  userRole: string,
  toolsForProvider: any[]
): string {
  return `SYSTEM
Vous exécutez le PLAN ci-dessous. Utilisez UNIQUEMENT les Tools autorisés.
Avant toute step.type="tool": vérifier confirmation_policy.
Si requires_confirmation=true: émettre "user_confirmation_requested" puis stop_reason="user_confirmation_required".
En cas de VALIDATION_ERROR: tentez l'auto-correction max 2 fois; sinon demandez une clarification.

Contexte:
- Route: ${currentRoute}
- Rôle: ${userRole}
- PLAN:
${JSON.stringify(plan, null, 2)}

- Tools (function-calling):
${JSON.stringify(toolsForProvider, null, 2)}

Instructions:
- Émettre des tool_calls pour les steps "tool".
- Résumer brièvement après chaque succès.
- Réponse finale claire + actions UI si utiles.
- Respecter les stop reasons: user_confirmation_required > missing_info > uncertainty > done > max_iterations.

Exécutez le plan maintenant.`;
}

/**
 * Build minimal tool documentation for Planner
 */
export function buildToolsSubsetDoc(tools: any[]): string {
  return tools
    .map((t) => {
      const params = Object.keys(t.parameters_schema?.properties || {}).join(', ');
      return `- ${t.key} (${t.category}): ${t.description}
  Params: {${params}}
  Risk: ${t.risk_level}, Confirmation: ${t.confirmation_policy}`;
    })
    .join('\n\n');
}

/**
 * Format tools for LLM provider (OpenAI, Gemini, Anthropic)
 */
export function formatToolsForProvider(
  tools: any[],
  provider: 'openai' | 'google' | 'anthropic'
): any {
  switch (provider) {
    case 'openai':
      return tools.map((t) => ({
        type: 'function',
        function: {
          name: t.key,
          description: t.description,
          parameters: t.parameters_schema,
        },
      }));

    case 'google':
      return {
        function_declarations: tools.map((t) => ({
          name: t.key,
          description: t.description,
          parameters: t.parameters_schema,
        })),
      };

    case 'anthropic':
      return tools.map((t) => ({
        name: t.key,
        description: t.description,
        input_schema: t.parameters_schema,
      }));

    default:
      throw new Error(`Unsupported provider: ${provider}`);
  }
}
