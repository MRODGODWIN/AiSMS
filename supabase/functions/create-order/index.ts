// Order creation is intentionally performed by the
// SECURITY DEFINER-safe database RPC
// public.create_order_from_cart, which derives prices
// from published products.

Deno.serve(async () =>
  new Response(
    JSON.stringify({
      error:
        "Use the create_order_from_cart RPC through the authenticated client.",
    }),
    {
      status: 410,
      headers: {
        "Content-Type": "application/json",
      },
    },
  )
);
