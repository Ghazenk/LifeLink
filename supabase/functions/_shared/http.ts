export class HttpError extends Error {
  constructor(public status: number, message: string) { super(message); }
}
export function cors(req: Request): HeadersInit {
  const origin = req.headers.get('origin');
  const allowed = (Deno.env.get('ALLOWED_ORIGINS') ?? '').split(',').map(x => x.trim()).filter(Boolean);
  if (origin && !allowed.includes(origin)) throw new HttpError(403, 'This web origin is not enabled.');
  return { ...(origin ? {'Access-Control-Allow-Origin': origin, 'Vary': 'Origin'} : {}),
    'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS', 'Cache-Control': 'no-store',
    'Content-Type': 'application/json', 'X-Content-Type-Options': 'nosniff' };
}
export function respond(body: unknown, status = 200, headers: HeadersInit = {}) {
  return new Response(JSON.stringify(body), {status, headers: {...headers, 'Content-Type': 'application/json', 'Cache-Control': 'no-store'}});
}
export async function jsonBody(req: Request, maxBytes = 16384): Promise<Record<string, unknown>> {
  if (!/^application\/json(?:\s*;\s*charset=utf-8)?$/i.test(req.headers.get('content-type') ?? '')) throw new HttpError(415, 'Use a JSON request.');
  const reader = req.body?.getReader();
  if (!reader) throw new HttpError(400, 'Request body required.');
  const chunks: Uint8Array[] = []; let size = 0;
  try {
    while (true) { const {value, done} = await reader.read(); if(done) break; size += value.length;
      if(size > maxBytes) { await reader.cancel(); throw new HttpError(413, 'Request is too large.'); } chunks.push(value); }
    const data = new Uint8Array(size); let offset=0; for(const chunk of chunks) {data.set(chunk,offset);offset+=chunk.length;}
    const body = JSON.parse(new TextDecoder().decode(data));
    if (!body || typeof body !== 'object' || Array.isArray(body)) throw new Error();
    return body;
  } catch(error) { if(error instanceof HttpError) throw error; throw new HttpError(400, 'Invalid JSON request.'); }
}
export async function requireUser(req: Request) {
  const authorization=req.headers.get('authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) throw new HttpError(401, 'Sign in to continue.');
  const url=Deno.env.get('SUPABASE_URL')!; const key=Deno.env.get('SUPABASE_ANON_KEY')!;
  const headers={Authorization:authorization,apikey:key,'Content-Type':'application/json'};
  const auth=await fetch(`${url}/auth/v1/user`,{headers,signal:AbortSignal.timeout(10000)});
  if (!auth.ok) throw new HttpError(401, 'Your session has expired. Sign in again.');
  const user=await auth.json();
  const response=await fetch(`${url}/rest/v1/profiles?id=eq.${encodeURIComponent(user.id)}&select=role,status`,{headers,signal:AbortSignal.timeout(10000)});
  if(!response.ok) throw new HttpError(503,'Account verification unavailable.');
  const profiles=await response.json(); const profile=profiles[0];
  if(!profile || profile.status!=='active') throw new HttpError(403,'An active account is required.');
  return {id:user.id as string,role:profile.role as string,url,headers};
}
export async function consumeApiQuota(
  actor: Awaited<ReturnType<typeof requireUser>>, kind: string, cost = 1,
) {
  const response = await fetch(`${actor.url}/rest/v1/rpc/consume_api_quota`, {
    method: 'POST', headers: actor.headers,
    body: JSON.stringify({kind, cost}), signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) throw new HttpError(503, 'Request protection is unavailable. Try again later.');
  if (await response.json() !== true) throw new HttpError(429, 'Too many requests. Try again later.');
}
export function safeError(error: unknown, headers: HeadersInit, endpoint = 'unknown') {
  const status = error instanceof HttpError ? error.status : 503;
  // Supabase Auth and the API gateway log request metadata separately. This
  // event deliberately omits bodies, query strings, IPs, emails and tokens.
  console.warn(JSON.stringify({event:'api_error', endpoint, status,
    category:status===429?'rate_limit':status===401||status===403?'access_denied':status>=500?'server_error':'bad_request'}));
  return error instanceof HttpError ? respond({error:error.message},status,headers)
    : respond({error:'The service is temporarily unavailable. Please try again.'},503,headers);
}
