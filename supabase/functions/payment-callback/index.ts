import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  try {
    const url = new URL(req.url);
    const reference = url.searchParams.get("reference");

    if (!reference) {
      return new Response("Missing payment reference", {
        status: 400,
        headers: cors,
      });
    }

    const paystackSecret = Deno.env.get("PAYSTACK_SECRET_KEY");

    if (!paystackSecret) {
      throw new Error("PAYSTACK_SECRET_KEY is not configured");
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");

    const supabaseSecret =
      Deno.env.get("SUPABASE_SECRET_KEY") ||
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseSecret) {
      throw new Error("Supabase server configuration is incomplete");
    }

    const supabase = createClient(
      supabaseUrl,
      supabaseSecret
    );

    const verifyResponse = await fetch(
      `https://api.paystack.co/transaction/verify/${encodeURIComponent(
        reference
      )}`,
      {
        headers: {
          Authorization: `Bearer ${paystackSecret}`,
        },
      }
    );

    const result = await verifyResponse.json();

    if (!verifyResponse.ok || !result.status) {
      throw new Error(
        result.message || "Payment verification failed"
      );
    }

    const transaction = result.data;

    const { data: payment, error: paymentError } =
      await supabase
        .from("payments")
        .select("id, order_id, amount, currency")
        .eq("reference", reference)
        .maybeSingle();

    if (paymentError) {
      throw paymentError;
    }

    if (!payment) {
      throw new Error("Payment record not found");
    }

    const expectedAmount =
      Math.round(Number(payment.amount) * 100);

    const paidSuccessfully =
      transaction.status === "success" &&
      Number(transaction.amount) === expectedAmount &&
      transaction.currency === payment.currency;

    await supabase
      .from("payments")
      .update({
        status: paidSuccessfully ? "paid" : "failed",
      })
      .eq("id", payment.id);

    await supabase
      .from("orders")
      .update({
        payment_status: paidSuccessfully ? "paid" : "failed",
        status: paidSuccessfully ? "paid" : "pending",
      })
      .eq("id", payment.order_id);

    return Response.redirect(
      url.origin +
        url.pathname.replace("/payment-callback", "") +
        "?payment=" +
        (paidSuccessfully ? "success" : "failed") +
        "&reference=" +
        encodeURIComponent(reference),
      303
    );

  } catch (error) {
    return new Response(
      error?.message || String(error),
      {
        status: 500,
        headers: {
          ...cors,
          "Content-Type": "text/plain",
        },
      }
    );
  }
});
