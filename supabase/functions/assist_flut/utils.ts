export function withTimeout<T>(p: Promise<T>, ms: number, signal?: AbortSignal): Promise<T> {
  return new Promise((resolve, reject) => {
    const id = setTimeout(() => {
      reject(new Error('TIMEOUT'));
    }, ms);
    if (signal) {
      signal.addEventListener('abort', () => {
        clearTimeout(id);
        reject(new Error('ABORTED'));
      }, { once: true });
    }
    p.then((v) => { clearTimeout(id); resolve(v); }, (e) => { clearTimeout(id); reject(e); });
  });
}

// Masquage PII simple (emails, numéros FR basiques)
export function maskPII(str: string): string {
  if (!str) return str;
  let s = str.replace(/([A-Z0-9._%+-]+)@([A-Z0-9.-]+\.[A-Z]{2,})/gi, '***@***');
  s = s.replace(/\b0[1-9](?:\s?\d{2}){4}\b/g, '0X XX XX XX XX');
  return s;
}
