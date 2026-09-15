import type { Env, RpcClient } from './types.js';
export async function documentAccess(id:string, actor:{id:string;aal:string}, rpc:RpcClient, env:Env):Promise<{url?:string;error?:string}> {
  if(env.PROVIDER_DOCUMENTS_ENABLED!=='true') return {error:'provider_documents_disabled'};
  const access=await rpc.call<{object_key?:string;error?:string}>('api_server_provider_document_access',{
    p_document_id:id,p_actor_user_id:actor.id,p_actor_aal:actor.aal,p_is_admin:true,
  },{admin:true});
  if(access.error) return {error:access.error};
  if(!/^provider-claims\/[a-f0-9-]{36}\/[a-f0-9-]{36}\.(pdf|png|jpe?g)$/.test(access.object_key??'')) return {error:'not_found'};
  let origin: URL;
  try { origin=new URL(env.SUPABASE_URL); } catch { return {error:'service_not_configured'}; }
  if(origin.protocol!=='https:' || origin.username || origin.password || origin.search || origin.hash || origin.pathname!=='/' || origin.port) return {error:'service_not_configured'};
  const secret=env.SUPABASE_SECRET_KEY??env.SUPABASE_SERVICE_ROLE_KEY;
  if(!secret) return {error:'service_not_configured'};
  let response: Response;
  try {
    response=await fetch(`${origin.origin}/storage/v1/object/sign/${access.object_key}`,{
      method:'POST',headers:{apikey:secret,authorization:`Bearer ${secret}`,'content-type':'application/json'},
      body:JSON.stringify({expiresIn:60}),redirect:'manual',signal:AbortSignal.timeout(10000),
    });
  } catch { return {error:'document_unavailable'}; }
  if(!response.ok || !response.body) return {error:'document_unavailable'};
  const reader=response.body.getReader(); const chunks:Uint8Array[]=[];let length=0;
  try {while(true) {const {value,done}=await reader.read();if(done)break;length+=value.length;if(length>16384){await reader.cancel();return {error:'document_unavailable'};}chunks.push(value);}}
  finally {reader.releaseLock();}
  const bytes=new Uint8Array(length);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length;}
  let result: {signedURL?:string};
  try { result=JSON.parse(new TextDecoder().decode(bytes)) as {signedURL?:string}; }
  catch { return {error:'document_unavailable'}; }
  if(!result.signedURL?.startsWith('/object/sign/provider-claims/')) return {error:'document_unavailable'};
  const url=new URL(`/storage/v1${result.signedURL}`,origin.origin);url.searchParams.set('download','evidencia');
  return {url:url.toString()};
}
