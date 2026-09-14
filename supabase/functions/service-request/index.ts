// Service requests are written directly to public.service_requests under RLS.
// This endpoint is reserved for future notification fan-out and deliberately performs no writes.

Deno.serve(async () =>
  new Response(
    JSON.stringify({
      ok: true,
    }),
    {
      headers: {
        "Content-Type": "application/json",
      },
    },
  )
);
