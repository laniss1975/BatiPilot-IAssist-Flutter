/**
 * Derive idempotency key from tool arguments
 *
 * Generates a deterministic SHA-256 hash based on:
 * - tool_key
 * - user_id
 * - selected argument fields (e.g. nom, prenom, email)
 *
 * Format: idem_{first_32_chars_of_hex}
 */

export async function deriveIdempotencyKey(
  toolKey: string,
  userId: string,
  args: Record<string, any>,
  fields: string[]
): Promise<string> {
  const picked: Record<string, any> = {};

  // Pick only specified fields
  for (const f of fields) {
    if (args[f] !== undefined) {
      picked[f] = args[f];
    }
  }

  // Canonical JSON (sorted keys for deterministic hash)
  const canonical = JSON.stringify(
    Object.keys(picked)
      .sort()
      .reduce((o, k) => {
        o[k] = picked[k];
        return o;
      }, {} as Record<string, any>)
  );

  // Build input string: tool_key|user_id|canonical_args
  const input = `${toolKey}|${userId}|${canonical}`;
  const data = new TextEncoder().encode(input);

  // SHA-256 hash
  const digest = await crypto.subtle.digest('SHA-256', data);
  const hex = Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');

  // Return first 32 chars with prefix
  return `idem_${hex.slice(0, 32)}`;
}
