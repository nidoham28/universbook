// supabase/functions/upsert-page/index.ts

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4"; // Fix 1: match import style used across the codebase

const url = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

function buildSearchQueue(title: string, content: string): string[] {
  const tokens = `${title} ${content}`
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .split(/\s+/)
    .filter((t) => t.length > 2);
  return [...new Set(tokens)].slice(0, 200);
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    // ── Authenticate caller ──────────────────────────────
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return json({ error: "unauthorized" }, 401);
    }
    const token = authHeader.replace("Bearer ", "");

    const admin = createClient(url, serviceKey);
    const { data: { user }, error: authError } = await admin.auth.getUser(token);
    if (authError || !user) return json({ error: "unauthorized" }, 401);

    // ── Payload ──────────────────────────────────────────
    const {
      stories_id,
      page_no,
      title,
      content,
      thumbnail,
      related_pages,
    } = await req.json();

    if (!stories_id) return json({ error: "stories_id required" }, 400);
    if (!title?.trim()) return json({ error: "title required" }, 400);
    if (!content?.trim()) return json({ error: "content required" }, 400);

    // ── Verify story ownership ───────────────────────────
    const { data: story, error: storyErr } = await admin
      .from("stories")
      .select("id, creator, page_count")
      .eq("id", stories_id)
      .single();

    if (storyErr || !story) return json({ error: "story not found" }, 404);
    if (story.creator !== user.id) return json({ error: "forbidden" }, 403);

    const cleanTitle = title.trim();
    const cleanContent = content.trim();
    const searchQueue = buildSearchQueue(cleanTitle, cleanContent);

    const common = {
      title: cleanTitle,
      content: cleanContent,
      content_length: cleanContent.length,
      thumbnail: thumbnail ?? null,
      related_pages: related_pages ?? [],
      search_queue: searchQueue,
      status: "public",
    };

    let result;

    if (page_no !== null && page_no !== undefined) {
      // ── Update existing page ─────────────────────────
      const { data, error } = await admin
        .from("pages")
        .update(common)
        .eq("story_id", stories_id)   // Fix 2: was "stories_id", column is "story_id"
        .eq("page_no", page_no)
        .eq("creator", user.id)
        .select();

      if (error) throw error;
      if (!data || data.length === 0) {
        return json({ error: "page not found or not owned by user" }, 404);
      }
      result = data[0];
    } else {
      // ── Append new page ──────────────────────────────
      const nextNo = story.page_count ?? 0;

      const { data, error } = await admin
        .from("pages")
        .insert({
          ...common,
          story_id: stories_id,        // Fix 3: was "stories_id", column is "story_id"
          creator: user.id,
          page_no: nextNo,
        })
        .select()
        .single();

      if (error) throw error;

      await admin
        .from("stories")
        .update({ page_count: nextNo + 1 })
        .eq("id", stories_id);

      result = data;
    }

    return json({ success: true, data: result }, 200);
  } catch (e) {
    console.error(e);
    return json({ error: (e as Error).message }, 500);
  }
});