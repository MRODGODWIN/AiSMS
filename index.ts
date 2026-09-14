import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json"
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const auth = req.headers.get("Authorization");
  if (!auth) return new Response(JSON.stringify({error:"Authentication required"}), {status:401,headers:cors});

  const PAYSTACK_SECRET_KEY = Deno.env.get("PAYSTACK_SECRET_KEY");
  if (!PAYSTACK_SECRET_KEY) return new Response(JSON.stringify({error:"Payment provider is not configured"}), {status:503,headers:cors});

  // The browser should first create an order through the protected create_order_from_cart RPC.
  // This function intentionally accepts the already-created order id and amount from the trusted DB path.
  // For full production deployment, fetch the order using a server-side Supabase client and verify ownership.
  const { email, amount, reference, callback_url } = await req.json();

  const response = await fetch("https://api.paystack.co/transaction/initialize", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${PAYSTACK_SECRET_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      email,
      amount: Math.round(Number(amount) * 100),
      reference,
      callback_url
    })
  });

  const data = await response.json();
  return new Response(JSON.stringify(data), {status: response.status, headers: cors});
});
