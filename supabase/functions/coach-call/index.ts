// Supabase Edge Function: Voice call management via Twilio
// Initiates outbound voice calls from the AI coach to the user.
// The call connects to a TwiML endpoint that drives a real-time AI voice conversation.
// Supports: initiate_call, end_call, schedule (for future check-in calls).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const TWILIO_ACCOUNT_SID = Deno.env.get("TWILIO_ACCOUNT_SID") || "";
const TWILIO_AUTH_TOKEN = Deno.env.get("TWILIO_AUTH_TOKEN") || "";
const TWILIO_PHONE_NUMBER = Deno.env.get("TWILIO_PHONE_NUMBER") || "";
const APP_BASE_URL = Deno.env.get("APP_BASE_URL") || "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Initiate an outbound call via Twilio
async function initiateCall(
  to: string,
  personality: string,
  context: string,
  userId: string,
): Promise<Record<string, unknown>> {
  const url = `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Calls.json`;
  const auth = btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`);

  // TwiML webhook URL — handles the AI conversation flow
  const twimlUrl = `${APP_BASE_URL}/functions/v1/coach-call-twiml?personality=${personality}&userId=${userId}&context=${encodeURIComponent(context)}`;

  const params = new URLSearchParams({
    To: to,
    From: TWILIO_PHONE_NUMBER,
    Url: twimlUrl,
    Method: "POST",
    StatusCallback: `${APP_BASE_URL}/functions/v1/coach-call-status`,
    StatusCallbackMethod: "POST",
    StatusCallbackEvent: "initiated ringing answered completed",
  });

  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: params.toString(),
  });

  return res.json();
}

// End an active call
async function endCall(callSid: string): Promise<void> {
  const url = `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Calls/${callSid}.json`;
  const auth = btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`);

  await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({ Status: "completed" }).toString(),
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Validate JWT
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN) {
      return new Response(
        JSON.stringify({ error: "Twilio not configured" }),
        {
          status: 503,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const body = await req.json();
    const action = body.action as string;

    switch (action) {
      case "initiate_call": {
        const result = await initiateCall(
          body.to,
          body.personality || "normal",
          body.context || "",
          user.id,
        );

        // Log the call
        await supabase.from("coach_calls").insert({
          user_id: user.id,
          direction: "outbound",
          personality: body.personality || "normal",
          twilio_sid: result.sid,
          status: "initiated",
        });

        return new Response(
          JSON.stringify({ success: true, callSid: result.sid }),
          {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }

      case "end_call": {
        // Find active call for this user
        const { data: calls } = await supabase
          .from("coach_calls")
          .select("twilio_sid")
          .eq("user_id", user.id)
          .eq("status", "in-progress")
          .order("created_at", { ascending: false })
          .limit(1);

        if (calls && calls.length > 0) {
          await endCall(calls[0].twilio_sid);
          await supabase
            .from("coach_calls")
            .update({ status: "completed" })
            .eq("twilio_sid", calls[0].twilio_sid);
        }

        return new Response(JSON.stringify({ success: true }), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      case "schedule": {
        // Store scheduled check-in for cron job to process
        await supabase.from("scheduled_check_ins").insert({
          user_id: user.id,
          type: body.type,
          scheduled_at: body.scheduled_at,
          personality: body.personality || "normal",
          message: body.message || null,
          channel: body.channel || "call",
          status: "pending",
        });

        return new Response(JSON.stringify({ success: true }), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      default:
        return new Response(
          JSON.stringify({ error: `Unknown action: ${action}` }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
    }
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
