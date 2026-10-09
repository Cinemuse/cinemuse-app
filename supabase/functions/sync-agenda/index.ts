import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";
const TMDB_API_KEY = Deno.env.get("TMDB_API_KEY") ?? "";
serve(async (req)=>{
  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
    if (!SUPABASE_URL) throw new Error("Missing SUPABASE_URL");
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY || SUPABASE_ANON_KEY || "");
    console.log("Starting global agenda sync...");
    const trackedItems = new Map();
    let singleSyncId = null;
    let singleSyncType = null;
    try {
      const body = await req.json();
      if (body && body.tmdb_id && body.media_type) {
        singleSyncId = body.tmdb_id;
        singleSyncType = body.media_type;
      }
    } catch (e) {}
    if (singleSyncId && singleSyncType) {
      console.log(`On-demand sync for ${singleSyncType} ${singleSyncId}`);
      trackedItems.set(`${singleSyncType}_${singleSyncId}`, {
        id: singleSyncId,
        type: singleSyncType
      });
    } else {
      const { data: watchHistory, error: whError } = await supabase.from("watch_history").select("tmdb_id, media_type, status");
      const { data: listItems, error: liError } = await supabase.from("list_items").select("tmdb_id, media_type");
      if (whError || liError) throw new Error(`Failed to fetch tracked items`);
      for (const item of watchHistory || []){
        if (item.media_type === "movie" && item.status === "completed") continue;
        trackedItems.set(`${item.media_type}_${item.tmdb_id}`, {
          id: item.tmdb_id,
          type: item.media_type
        });
      }
      for (const item of listItems || []){
        trackedItems.set(`${item.media_type}_${item.tmdb_id}`, {
          id: item.tmdb_id,
          type: item.media_type
        });
      }
    }
    const delay = (ms)=>new Promise((res)=>setTimeout(res, ms));
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    const cutoffDateStr = thirtyDaysAgo.toISOString().split("T")[0];
    for (const item of trackedItems.values()){
      if (!singleSyncId) await delay(40);
      try {
        if (item.type === "movie") {
          const tmdbRes = await fetch(`https://api.themoviedb.org/3/movie/${item.id}?api_key=${TMDB_API_KEY}&language=en-US`);
          if (!tmdbRes.ok) continue;
          const data = await tmdbRes.json();
          // Skip movies released more than 30 days ago
          if (data.release_date && data.release_date < cutoffDateStr) {
            continue;
          }
          const payload = {
            tmdb_id: item.id,
            media_type: "movie",
            release_date: data.release_date || null,
            event_data: data,
            updated_at: new Date().toISOString()
          };
          await supabase.from("upcoming_agenda_cache").upsert(payload, {
            onConflict: "tmdb_id,media_type"
          });
        } else if (item.type === "tv") {
          const tmdbRes = await fetch(`https://api.themoviedb.org/3/tv/${item.id}?api_key=${TMDB_API_KEY}&language=en-US`);
          if (!tmdbRes.ok) continue;
          const seriesData = await tmdbRes.json();
          if (seriesData.status === "Ended" || seriesData.status === "Canceled") continue;
          const nextEpisode = seriesData.next_episode_to_air;
          if (nextEpisode) {
            // Fetch the FULL season details for the next episode's season to get ALL upcoming episodes
            await delay(20);
            const seasonRes = await fetch(`https://api.themoviedb.org/3/tv/${item.id}/season/${nextEpisode.season_number}?api_key=${TMDB_API_KEY}&language=en-US`);
            if (!seasonRes.ok) continue;
            const seasonData = await seasonRes.json();
            const eventData = {
              ...seasonData,
              series_name: seriesData.name,
              series_poster_path: seriesData.poster_path
            };
            const payload = {
              tmdb_id: item.id,
              media_type: "tv",
              release_date: nextEpisode.air_date || null,
              event_data: eventData,
              updated_at: new Date().toISOString()
            };
            await supabase.from("upcoming_agenda_cache").upsert(payload, {
              onConflict: "tmdb_id,media_type"
            });
          }
        }
      } catch (err) {
        console.error(`Error processing ${item.type} ${item.id}`, err);
      }
    }
    if (!singleSyncId) {
      await supabase.from("upcoming_agenda_cache").delete().lt("release_date", cutoffDateStr);
    }
    return new Response(JSON.stringify({
      success: true,
      count: trackedItems.size
    }), {
      headers: {
        "Content-Type": "application/json"
      }
    });
  } catch (err) {
    return new Response(JSON.stringify({
      error: err.message
    }), {
      status: 500,
      headers: {
        "Content-Type": "application/json"
      }
    });
  }
});
