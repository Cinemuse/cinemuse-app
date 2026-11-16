/** The public Storage bucket `livetv`, as the service role. */
export interface BucketDeps {
  supabaseUrl: string;
  serviceKey: string;
  fetch: typeof fetch;
}

export const bucket = "livetv";

/** A file's text; null when it doesn't exist yet. Read through the API, not
 * the public address, so a cached old copy is never read. */
export async function readFile(
  deps: BucketDeps,
  name: string,
): Promise<string | null> {
  const res = await deps.fetch(
    `${deps.supabaseUrl}/storage/v1/object/${bucket}/${name}`,
    { headers: auth(deps) },
  );
  if (res.ok) return await res.text();
  const body = await res.text();
  // Storage answers a missing file with 400 or 404, "not_found" in the body.
  if (res.status === 404 || (res.status === 400 && /not.?found/i.test(body))) {
    return null;
  }
  throw new Error(`read ${name}: ${res.status} ${body}`);
}

/** Writes (or replaces) a file. */
export async function writeFile(
  deps: BucketDeps,
  name: string,
  body: string,
  contentType: string,
  cacheSeconds: number,
): Promise<void> {
  const res = await deps.fetch(
    `${deps.supabaseUrl}/storage/v1/object/${bucket}/${name}`,
    {
      method: "POST",
      headers: {
        ...auth(deps),
        "Content-Type": contentType,
        "Cache-Control": `max-age=${cacheSeconds}`,
        "x-upsert": "true",
      },
      body,
    },
  );
  if (!res.ok) {
    throw new Error(`write ${name}: ${res.status} ${await res.text()}`);
  }
  await res.body?.cancel();
}

function auth(deps: BucketDeps): Record<string, string> {
  return {
    apikey: deps.serviceKey,
    Authorization: `Bearer ${deps.serviceKey}`,
  };
}
