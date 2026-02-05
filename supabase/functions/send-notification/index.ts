// Supabase Edge Function: send-notification
// Sends push notifications via APNs (Apple Push Notification service)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.8/mod.ts";

// Environment variables (set in Supabase dashboard)
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID")!;
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID")!;
const APNS_PRIVATE_KEY = Deno.env.get("APNS_PRIVATE_KEY")!;
const BUNDLE_ID = Deno.env.get("BUNDLE_ID") || "com.davidpark.TOY";
const APNS_HOST = Deno.env.get("APNS_PRODUCTION") === "true"
  ? "api.push.apple.com"
  : "api.sandbox.push.apple.com";

interface NotificationRequest {
  user_ids: string[];
  title: string;
  body: string;
  data?: Record<string, string>;
}

serve(async (req) => {
  try {
    // Only allow POST
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    const { user_ids, title, body, data }: NotificationRequest = await req.json();

    if (!user_ids || user_ids.length === 0) {
      return new Response(JSON.stringify({ error: "user_ids required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Initialize Supabase client with service role
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Get device tokens for the specified users
    const { data: tokens, error } = await supabase
      .from("device_tokens")
      .select("token, user_id")
      .in("user_id", user_ids);

    if (error) {
      console.error("Error fetching tokens:", error);
      return new Response(JSON.stringify({ error: "Failed to fetch tokens" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ sent: 0, message: "No tokens found" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Generate APNs JWT
    const jwt = await generateAPNsJWT();

    // Send notification to each device
    const results = await Promise.allSettled(
      tokens.map((t) => sendAPNs(t.token, { title, body, data }, jwt))
    );

    // Count successes and failures
    const sent = results.filter((r) => r.status === "fulfilled").length;
    const failed = results.filter((r) => r.status === "rejected").length;

    // Clean up invalid tokens
    const invalidTokens = results
      .map((r, i) => (r.status === "rejected" ? tokens[i].token : null))
      .filter(Boolean);

    if (invalidTokens.length > 0) {
      await supabase
        .from("device_tokens")
        .delete()
        .in("token", invalidTokens);
      console.log(`Cleaned up ${invalidTokens.length} invalid tokens`);
    }

    return new Response(
      JSON.stringify({ sent, failed, total: tokens.length }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    console.error("Error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

/**
 * Generates a JWT for APNs authentication.
 * Token is valid for up to 1 hour per Apple's requirements.
 */
async function generateAPNsJWT(): Promise<string> {
  // Import the private key
  const pemContents = APNS_PRIVATE_KEY.replace(/\\n/g, "\n");
  const pemLines = pemContents
    .split("\n")
    .filter((line) => !line.includes("-----"));
  const keyData = Uint8Array.from(atob(pemLines.join("")), (c) =>
    c.charCodeAt(0)
  );

  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  // Create JWT
  const jwt = await create(
    { alg: "ES256", kid: APNS_KEY_ID },
    {
      iss: APNS_TEAM_ID,
      iat: getNumericDate(new Date()),
    },
    key
  );

  return jwt;
}

/**
 * Sends a push notification to a specific device via APNs.
 */
async function sendAPNs(
  deviceToken: string,
  payload: { title: string; body: string; data?: Record<string, string> },
  jwt: string
): Promise<void> {
  const url = `https://${APNS_HOST}/3/device/${deviceToken}`;

  const response = await fetch(url, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": BUNDLE_ID,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      aps: {
        alert: {
          title: payload.title,
          body: payload.body,
        },
        sound: "default",
      },
      ...payload.data,
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    console.error(`APNs error for ${deviceToken.substring(0, 10)}...: ${response.status} ${errorBody}`);

    // If token is invalid, throw to trigger cleanup
    if (response.status === 400 || response.status === 410) {
      throw new Error(`Invalid token: ${response.status}`);
    }
  }
}
