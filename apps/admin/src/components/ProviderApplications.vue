<script setup lang="ts">
import { onMounted, onUnmounted, ref } from 'vue';
import type { AdminApi } from '../api';
import { formatDate } from '../api';
const props = defineProps<{ api: AdminApi }>();
const documentUrl=ref('');
const changes=ref<Record<string,any>[]>([]);
async function loadChanges() { try { const value=await props.api.providerChanges();if(alive)changes.value=value; } catch { error.value='No se pudieron cargar las correcciones.'; } }
async function reviewChange(item:Record<string,any>,decision:string) { if(!item.review_reason?.trim())return; try {await props.api.reviewProviderChange(item.request_id,decision,item.review_reason);await loadChanges();}catch{error.value='No se pudo guardar la decisión.';} }
async function documentAction(id:string,decision?:string) {
  error.value='';documentUrl.value='';
  try {
    const result=await props.api.providerDocument(id,decision?'review':'access',decision?{decision,reason:message.value}:{});
    if(!alive) return;
    if(!decision) { const url=new URL(result.url);if(url.protocol!=='https:')throw Error();documentUrl.value=url.href; }
    else if(detail.value) await open(detail.value.id);
  } catch { if(alive)error.value='El documento todavía no está disponible o no pasó sus controles.'; }
}
const rows = ref<Record<string, any>[]>([]), detail = ref<Record<string, any> | null>(null);
const q = ref(''), status = ref(''), days = ref(''), offset = ref(0), error = ref(''), notice = ref('');
const busy = ref(false), message = ref(''), source = ref(''), orgQuery = ref(''), organization = ref('');
const organizations = ref<Record<string, string>[]>([]), scopeConfirmed = ref(false), privacy = ref<Record<string, any>[]>([]);
let alive = true, generation = 0;
const labels: Record<string,string> = { draft:'Borrador',pending:'Recibida',under_review:'En revisión',needs_information:'Esperando respuesta',approved:'Aprobada',rejected:'No aprobada',cancelled:'Cancelada',revoked:'Revocada' };
async function load(reset = false) {
  if (reset) offset.value=0;
  const current=++generation; busy.value=true; error.value='';
  try { const data=await props.api.providerApplications(`?${new URLSearchParams({q:q.value,status:status.value,days:days.value,offset:String(offset.value)})}`);
    if(alive && current===generation) rows.value=data.items;
  } catch(e) { if(alive) error.value=e instanceof Error?e.message:'No se pudieron cargar las solicitudes.'; }
  finally { if(alive && current===generation) busy.value=false; }
}
async function open(id:string) { busy.value=true; error.value=''; try {
  const value=await props.api.providerApplications(`/${id}`); if(alive) { detail.value=value; message.value=''; scopeConfirmed.value=false; }
} catch(e) { if(alive) error.value=e instanceof Error?e.message:'No se pudo abrir el expediente.'; } finally { if(alive) busy.value=false; } }
async function act(action:string) {
  if(!detail.value || busy.value) return;
  const id=detail.value.id; busy.value=true; error.value=''; notice.value='';
  try {
    await props.api.providerApplications(`/${id}/${action}`, {revision:detail.value.revision,message:message.value,source_url:source.value,organization_id:organization.value,scope_confirmed:scopeConfirmed.value});
    if(alive) { notice.value='Cambio guardado. El seguimiento está actualizado.'; await open(id); await load(); }
  } catch(e) { if(alive) error.value=e instanceof Error?e.message:'No se pudo guardar.'; } finally { if(alive) busy.value=false; }
}
async function findOrganizations() { error.value=''; try { const value=await props.api.providerApplications(`/organizations?q=${encodeURIComponent(orgQuery.value)}`); if(alive) organizations.value=value.items; } catch { error.value='No se pudieron buscar organizaciones.'; } }
async function loadPrivacy() { error.value=''; try { const value=await props.api.providerApplications('/privacy_list'); if(alive) privacy.value=value.items; } catch { error.value='No se pudieron cargar las solicitudes de privacidad.'; } }
async function answerPrivacy(item:Record<string,any>) { if(!item.reply?.trim()) return; try { await props.api.providerApplications(`/${item.id}/privacy_answer`,{revision:0,message:item.reply}); await loadPrivacy(); } catch { error.value='No se pudo guardar la respuesta.'; } }
onMounted(()=>load()); onUnmounted(()=>{alive=false;generation++;});
</script>
<template>
  <main class="panel claims-panel">
    <h2>Solicitudes de proveedores</h2><p>Comprueba quién representa el negocio y el alcance que solicita.</p>
    <details><summary @click="loadChanges">Correcciones de perfiles propuestas</summary><article v-for="item in changes" :key="item.request_id"><h3>{{ item.provider_name }} · {{ item.provider_location_name }}</h3><dl><template v-for="(value,key) in item.changes" :key="key"><dt>{{ key }}</dt><dd>{{ value }}</dd></template></dl><label>Motivo<textarea v-model="item.review_reason" maxlength="2000"></textarea></label><button @click="reviewChange(item,'approved')">Aprobar corrección</button><button @click="reviewChange(item,'rejected')">Rechazar corrección</button></article></details>
    <form class="panel-tools" @submit.prevent="load(true)"><input v-model="q" aria-label="Buscar solicitudes" placeholder="Negocio, representante o empresa" maxlength="160"><button :disabled="busy">Buscar</button></form>
    <div class="claim-filters"><button v-for="[key,label] in [['','Todas'],['pending','Nuevas'],['under_review','En revisión'],['needs_information','Esperando respuesta'],['approved','Aprobadas'],['rejected','No aprobadas'],['cancelled','Canceladas'],['revoked','Revocadas']]" :key="key" :aria-pressed="status===key" @click="status=key;load(true)">{{ label }}</button></div>
    <div class="claim-filters"><button v-for="[key,label] in [['','Todo el tiempo'],['15','Últimos 15 días'],['30','Últimos 30 días']]" :key="key" :aria-pressed="days===key" @click="days=key;load(true)">{{ label }}</button></div>
    <p v-if="error" role="alert" class="alert error">{{ error }}</p><p v-if="notice" role="status">{{ notice }}</p>
    <div class="table-wrap"><table><thead><tr><th>Perfil</th><th>Representante</th><th>Estado</th><th>Fecha</th><th></th></tr></thead><tbody><tr v-for="row in rows" :key="row.id"><td>{{ row.provider_name }}<small class="block">{{ row.location_name || 'Toda la marca' }}</small></td><td>{{ row.name }}<small class="block">{{ row.organization_name }}</small></td><td>{{ labels[row.status] }}</td><td>{{ formatDate(row.created_at) }}</td><td><button :disabled="busy" @click="open(row.id)">Revisar</button></td></tr></tbody></table></div>
    <p v-if="!busy && !rows.length">No hay solicitudes con estos filtros.</p>
    <div class="panel-tools"><button :disabled="busy || offset===0" @click="offset-=50;load()">Anterior</button><span>Página {{ offset/50+1 }}</span><button :disabled="busy || rows.length<50" @click="offset+=50;load()">Siguiente</button></div>
    <section v-if="detail" class="claim-detail">
      <button @click="detail=null">Cerrar expediente</button><h3>{{ detail.organization_name }} · {{ labels[detail.status] }}</h3>
      <p>{{ detail.name }} · {{ detail.position }} · {{ detail.work_email }}</p><p>Alcance: {{ detail.scope==='brand'?'Toda la marca':'Una sucursal' }}. Folio {{ detail.id }}</p>
      <p>Contacto oficial: {{ detail.contact_reviewed_by?'Fuente revisada':'Pendiente de revisión' }} · Correo: {{ detail.contact_confirmed_at?'Comprobado':'Sin comprobar' }}</p>
      <p v-if="!detail.organization_id">Relaciona la empresa declarada con una organización canónica. Si falta, requiere validar su alta antes de aprobar.</p>
      <div v-if="!detail.organization_id"><input v-model="orgQuery" placeholder="Buscar razón social"><button @click="findOrganizations">Buscar empresa</button><label v-for="org in organizations" :key="org.id"><input v-model="organization" type="radio" :value="org.id">{{ org.legal_name }}</label><button :disabled="busy || !organization" @click="act('bind_organization')">Confirmar organización</button></div>
      <label>Fuente oficial del correo<input v-model="source" type="url" placeholder="https://sitio-oficial/" maxlength="1000"></label>
      <label>Mensaje o justificación<textarea v-model="message" maxlength="2000" rows="3" placeholder="Explica qué revisaste o qué información falta."></textarea></label>
      <button v-if="!detail.organization_id" :disabled="busy || message.trim().length<10" @click="act('create_organization')">Crear organización con la razón social revisada</button>
      <div class="claim-filters"><button :disabled="busy || message.trim().length<10 || !source" @click="act('verify_contact')">Validar fuente del contacto</button><button :disabled="busy || !detail.contact_reviewed_by" @click="act('send_verification')">Enviar comprobación al correo</button><button :disabled="busy || !message.trim()" @click="act('note')">Guardar como nota interna</button></div>
      <label><input v-model="scopeConfirmed" type="checkbox">Revisé la representación y confirmo el alcance {{ detail.scope==='brand'?'de toda la marca':'de esta sucursal' }}.</label>
      <div class="claim-filters"><button :disabled="busy || detail.status!=='pending'" @click="act('take')">Tomar revisión</button><button :disabled="busy || !message.trim()" @click="act('request_information')">Pedir información</button><button :disabled="busy || !scopeConfirmed || message.trim().length<10" @click="act('approve')">Aprobar acceso</button><button :disabled="busy || !message.trim()" @click="act(detail.status==='approved'?'revoke':'reject')">{{ detail.status==='approved'?'Revocar acceso':'Rechazar solicitud' }}</button></div>
      <h4>Documentos</h4><p v-if="!detail.documents?.length">No hay documentos. El correo oficial comprobado puede servir como evidencia.</p><div v-for="doc in detail.documents" :key="doc.id"><p>{{ doc.type }} · {{ doc.scan_status }} · {{ doc.status }}</p><button :disabled="doc.scan_status!=='clean'" @click="documentAction(doc.id)">Preparar descarga privada</button><button :disabled="doc.scan_status!=='clean'" @click="documentAction(doc.id,'accepted')">Aceptar evidencia</button><button :disabled="!message.trim()" @click="documentAction(doc.id,'rejected')">Rechazar evidencia</button></div><a v-if="documentUrl" :href="documentUrl" target="_blank" rel="noopener noreferrer">Descargar evidencia (enlace válido por 60 segundos)</a>
      <h4>Historial</h4><ol><li v-for="event in detail.events" :key="event.id">{{ formatDate(event.created_at) }} · {{ event.action }} <strong v-if="event.internal">(interno)</strong><p>{{ event.message }}</p></li></ol>
      <h4>Entrega de correos</h4><p v-for="(mail,index) in detail.mail" :key="index">{{ mail.kind }} · {{ mail.status }} · Intentos: {{ mail.attempts }}</p>
    </section>
    <details><summary @click="loadPrivacy">Solicitudes sobre datos personales</summary><article v-for="item in privacy" :key="item.id"><h4>{{ item.kind }} · {{ item.status }}</h4><p>{{ item.message }}</p><p>{{ item.response }}</p><textarea v-if="item.status!=='answered'" v-model="item.reply" aria-label="Respuesta de privacidad" maxlength="2000"></textarea><button v-if="item.status!=='answered'" @click="answerPrivacy(item)">Registrar respuesta</button></article></details>
  </main>
</template>
<style scoped>
.claims-panel { padding:24px; } .claim-filters { display:flex; flex-wrap:wrap; gap:8px; margin:12px 0; }
.claim-filters button { border-radius:999px; } button[aria-pressed=true] { font-weight:700; text-decoration:underline; }
.claim-detail { border-top:1px solid var(--border); margin-top:24px; padding-top:24px; } label { display:block; margin:12px 0; }
input:not([type=checkbox]):not([type=radio]),textarea { display:block; width:min(100%,600px); } li p { white-space:pre-wrap; }
</style>
