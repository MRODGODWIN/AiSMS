import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const json = (body: any, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  try {
    const auth = req.headers.get("Authorization");

    if (!auth) {
      return json({ error: "Authentication required" }, 401);
    }

    const url = Deno.env.get("SUPABASE_URL");
    const publishable =
      Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ||
      Deno.env.get("SUPABASE_ANON_KEY");

    const secretKey =
      Deno.env.get("SUPABASE_SECRET_KEY") ||
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!url || !publishable || !secretKey) {
      return json(
        { error: "Supabase server configuration is incomplete" },
        500
      );
    }

    const userClient = createClient(url, publishable, {
      global: { headers: { Authorization: auth } },
    });

    const admin = createClient(url, secretKey);

    const {
      data: { user },
      error: ue,
    } = await userClient.auth.getUser();

    if (ue || !user) {
      return json({ error: "Invalid session" }, 401);
    }

    const { order_id } = await req.json();

    if (!order_id) {
      return json({ error: "order_id is required" }, 400);
    }

    const { data: order, error: oe } = await admin
      .from("orders")
      .select(
        "id,order_number,buyer_id,total,currency,payment_status"
      )
      .eq("id", order_id)
      .eq("buyer_id", user.id)
      .maybeSingle();

    if (oe) throw oe;

    if (!order) {
      return json({ error: "Order not found" }, 404);
    }

    if (Number(order.total) <= 0) {
      return json(
        { error: "Order total must be greater than zero" },
        400
      );
    }

    if (order.payment_status === "paid") {
      return json({ error: "Order is already paid" }, 409);
    }

    const secret = Deno.env.get("PAYSTACK_SECRET_KEY");

    if (!secret) {
      return json(
        { error: "PAYSTACK_SECRET_KEY is not configured" },
        500
      );
    }

    const callback =
      Deno.env.get("PAYSTACK_CALLBACK_URL") ||
      `${url}/functions/v1/payment-callback`;

    const reference =
      order.order_number + "-" + crypto.randomUUID().slice(0, 8);

    const amount = Math.round(Number(order.total) * 100);

    const res = await fetch(
      "https://api.paystack.co/transaction/initialize",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${secret}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          email: user.email,
          amount,
          currency: order.currency,
          reference,
          callback_url: callback,
          metadata: { order_id: order.id },
        }),
      }
    );

    const pay = await res.json();

    if (!res.ok || !pay.status) {
      return json(
        { error: pay.message || "Paystack initialization failed" },
        502
      );
    }

    const { error: pe } = await admin.from("payments").insert({
      order_id: order.id,
      provider: "paystack",
      reference,
      amount: Number(order.total),
      currency: order.currency,
      status: "initialized",
    });

    if (pe) throw pe;

    await admin
      .from("orders")
      .update({
        payment_reference: reference,
        payment_status: "initialized",
      })
      .eq("id", order.id);

    return json({
      authorization_url: pay.data.authorization_url,
      reference,
      order_id: order.id,
    });
  } catch (e) {
    return json(
      { error: e?.message || String(e) },
      500
    );
  }
});
