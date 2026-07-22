// supabase/functions/create-story/index.ts
//
// Creates a new row in the `stories` table for the currently authenticated
// user. Client-supplied data is limited to the fields an author is allowed
// to set (title, thumbnail, category, tags, paid/cost, status);
// everything else — id, creator, timestamps, banned, verified, counts,
// rating fields, page_count, search_queue, related — is computed
// server-side using the service-role client so it can never be spoofed
// from the client payload.
//
// Deploy with: supabase functions deploy create-story

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const ALLOWED_STATUSES = new Set(["draft", "private", "public"]);
const MAX_TAGS = 10;
const MAX_TITLE_LENGTH = 200;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return json({ error: "Missing Authorization header" }, 401);
  }

  // Client scoped to the caller's JWT — used only to identify who is
  // calling, never to write to the table.
  const callerClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await callerClient.auth.getUser();
  if (userError || !userData?.user) {
    return json({ error: "Invalid or expired session" }, 401);
  }
  const creatorId = userData.user.id;

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const title = typeof body.title === "string" ? body.title.trim() : "";
  const thumbnail = typeof body.thumbnail === "string" ? body.thumbnail.trim() : "";
  const category = typeof body.category === "string" ? body.category.trim() : "";
  const tags = Array.isArray(body.tags)
    ? body.tags.filter((t): t is string => typeof t === "string").slice(0, MAX_TAGS)
    : [];
  const isPaid = body.isPaid === true;
  const costRaw = body.cost;
  const cost = typeof costRaw === "number" ? costRaw : Number(costRaw ?? 0);
  const statusRaw = typeof body.status === "string" ? body.status : "draft";
  const status = ALLOWED_STATUSES.has(statusRaw) ? statusRaw : "draft";

  if (!title) return json({ error: "title is required" }, 400);
  if (title.length > MAX_TITLE_LENGTH) {
    return json({ error: `title must be ${MAX_TITLE_LENGTH} characters or fewer` }, 400);
  }
  if (!thumbnail) return json({ error: "thumbnail is required" }, 400);
  if (!category) return json({ error: "category is required" }, 400);
  if (isPaid && (!Number.isFinite(cost) || cost <= 0)) {
    return json({ error: "cost must be a positive number for paid stories" }, 400);
  }

  // Service-role client for the actual insert, so server-only defaults
  // below are authoritative regardless of what the client sent.
  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const now = new Date().toISOString();
  const record = {
    creator: creatorId,
    created_at: now,
    updated_at: now,
    title,
    thumbnail,
    // A brand-new story has no pages yet. page_count is derived from the
    // `pages` table exclusively via upsert-page's append_page() — never
    // client-supplied, or the two can drift and corrupt page numbering.
    page_count: 0,
    status,
    banned: false,
    views_count: 0,
    likes_count: 0,
    category,
    tags,
    rating_sum: 0,
    rating_time: 0,
    verified: false,
    cost: isPaid ? cost : 0,
    is_paid: isPaid,
    // Only queue newly-public stories for search indexing; drafts and
    // private stories stay out of the index until published.
    search_queue: status === "public",
    related: [],
  };

  const { data, error } = await adminClient
    .from("stories")
    .insert(record)
    .select()
    .single();

  if (error) {
    return json({ error: error.message }, 500);
  }

  return json({ story: data }, 201);
});