/**
 * SSE (Server-Sent Events) Helper
 *
 * Features:
 * - Sequential event IDs for reconnection
 * - Retry directive (10s)
 * - Heartbeat every 25s to maintain connection
 * - Proper cleanup on cancel
 */

export type SSEEvent = {
  event: string;
  data: any;
  run_id?: string;
};

export function createSSEStream() {
  const enc = new TextEncoder();
  let seq = 0;
  let keepaliveTimer: number | undefined;

  const stream = new ReadableStream({
    start(controller) {
      // Send retry directive at the beginning
      controller.enqueue(enc.encode(`retry: 10000\n`));

      // Event sender function
      const send = (event: string, data: any) => {
        const id = ++seq;
        const payload = {
          ...data,
          ts: new Date().toISOString(),
        };

        controller.enqueue(enc.encode(`id: ${id}\n`));
        controller.enqueue(enc.encode(`event: ${event}\n`));
        controller.enqueue(enc.encode(`data: ${JSON.stringify(payload)}\n\n`));
      };

      // Heartbeat every 25s to keep connection alive
      keepaliveTimer = setInterval(() => {
        controller.enqueue(enc.encode(`event: heartbeat\n`));
        controller.enqueue(enc.encode(`data: {"ts":"${new Date().toISOString()}"}\n\n`));
      }, 25_000) as unknown as number;

      // Expose send function
      (stream as any)._send = send;
      (stream as any)._controller = controller;
    },

    cancel() {
      // Clean up heartbeat timer
      if (keepaliveTimer !== undefined) {
        clearInterval(keepaliveTimer);
      }
    },
  });

  return {
    stream,
    send: (stream as any)._send as (event: string, data: any) => void,
    close: () => {
      const controller = (stream as any)._controller;
      if (controller) {
        try {
          controller.close();
        } catch (e) {
          // Already closed
        }
      }
      if (keepaliveTimer !== undefined) {
        clearInterval(keepaliveTimer);
      }
    },
  };
}

/**
 * Create SSE Response with proper headers
 */
export function createSSEResponse(stream: ReadableStream): Response {
  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      'Connection': 'keep-alive',
      'X-Accel-Buffering': 'no', // Disable nginx buffering
    },
  });
}

/**
 * SSE Event Types
 */
export const SSE_EVENTS = {
  AGENT_STARTED: 'agent_started',
  PLAN_READY: 'plan_ready',
  TOOL_CALL_STARTED: 'tool_call_started',
  TOOL_CALL_SUCCEEDED: 'tool_call_succeeded',
  TOOL_CALL_FAILED: 'tool_call_failed',
  USER_CONFIRMATION_REQUESTED: 'user_confirmation_requested',
  ANSWER_PARTIAL: 'answer_partial',
  ANSWER_FINAL: 'answer_final',
  AGENT_ERROR: 'agent_error',
  AGENT_FINISHED: 'agent_finished',
  HEARTBEAT: 'heartbeat',
} as const;
