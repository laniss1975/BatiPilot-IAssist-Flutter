import { ToolDefinition } from "./types.ts";

export async function loadToolsForRoute(supabase: any, userId: string, currentRoute?: string): Promise<ToolDefinition[]> {
  // Règles:
  // - Tools système enabled
  // - + Tools user enabled
  // - Gating par route si enabled_from_routes est non-null
  const { data, error } = await supabase
    .from('ai_tools')
    .select('*')
    .eq('enabled', true);

  if (error) throw error;

  let tools = data || [];

  // Filtrage par route
  if (currentRoute) {
    tools = tools.filter((t: any) => {
      if (!t.enabled_from_routes || t.enabled_from_routes.length === 0) return true;
      return t.enabled_from_routes.includes(currentRoute);
    });
  }

  return tools;
}
