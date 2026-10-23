import {providerRequest, parseProviderResult} from './provider.ts';
import {consumeApiQuota, cors, HttpError, jsonBody, requireUser, respond, safeError} from '../_shared/http.ts';
import {validateInput, doctorNotice} from './validation.ts';

Deno.serve(async req => {
 let headers: HeadersInit = {};
 try {
  headers=cors(req); if(req.method==='OPTIONS') return new Response(null,{status:204,headers});
  if(!['GET','POST'].includes(req.method)) throw new HttpError(405,'Use GET or POST.');
  const actor=await requireUser(req);
  if(!['donor','patient'].includes(actor.role)) throw new HttpError(403,'Meal drafts are available to donors and patients.');
  const provider=Deno.env.get('AI_PROVIDER')??'groq';
  const endpoint=provider==='groq'?'https://api.groq.com/openai/v1/chat/completions':provider==='xai'?'https://api.x.ai/v1/chat/completions':null;
  const apiKey=Deno.env.get('AI_API_KEY'); const model=Deno.env.get('AI_MODEL')??(provider==='groq'?'openai/gpt-oss-120b':undefined);
  const configured=Boolean(endpoint&&apiKey&&model);
  if(req.method==='GET') {
   await consumeApiQuota(actor,'meal_status');
   return respond({configured,provider:provider==='xai'?'xAI Grok':'Groq',doctor_notice:doctorNotice},200,headers);
  }
  if(!configured) throw new HttpError(503,'AI meal drafts are not enabled yet. Ask your administrator to configure the provider.');
  const preferences=validateInput(await jsonBody(req,2048));
  const quota=await fetch(`${actor.url}/rest/v1/rpc/consume_ai_quota`,{method:'POST',headers:actor.headers,body:'{}',signal:AbortSignal.timeout(10000)});
  if(!quota.ok) throw new HttpError(quota.status===403?403:429,'Meal draft limit reached or account unavailable. Please try again later.');
  // No identity, blood group, lab values, diagnoses, or free-text health data go to the AI provider.
  const response=await fetch(endpoint!,{method:'POST',signal:AbortSignal.timeout(25000),
   headers:{Authorization:`Bearer ${apiKey}`,'Content-Type':'application/json'},
   body:JSON.stringify(providerRequest(provider,model!,preferences)),
  });
  if(response.status===429) throw new HttpError(429,'The AI provider is busy. Try again later.');
  if(!response.ok) throw new HttpError(502,'The AI provider could not produce a draft.');
  const result=await response.json();
  let plan;
  try {plan=parseProviderResult(result,preferences.preference);}
  catch(_) {throw new HttpError(502,'The AI draft did not pass validation. Ask your clinician for guidance.');}
  return respond({plan,doctor_notice:doctorNotice,provider:provider==='xai'?'xAI Grok':'Groq',generated_at:new Date().toISOString()},200,headers);
 } catch(error) {return safeError(error,headers,'meal-plan');}
});
