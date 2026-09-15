import type { RpcClient } from './types.js';

const providerActions = new Set(['create', 'save', 'submit', 'cancel', 'send_verification', 'verify', 'privacy_request']);
const adminActions = new Set(['take', 'request_information', 'note', 'bind_organization', 'create_organization', 'verify_contact', 'send_verification', 'approve', 'reject', 'revoke', 'privacy_answer']);
const messages: Record<string, string> = {
  intake_disabled: 'El registro de proveedores todavía no está abierto.',
  account_email_required: 'Confirma un correo en tu cuenta para recibir el seguimiento de la solicitud.',
  not_found: 'No encontramos esta solicitud.',
  stale_revision: 'La solicitud cambió. Actualiza antes de continuar.',
  invalid_transition: 'Esta acción no está disponible en el estado actual.',
  consent_required: 'Revisa el aviso vigente y confirma tu autorización.',
  contact_review_required: 'Primero revisaremos que el correo corresponda al negocio.',
  verification_expired: 'El enlace ya se utilizó o venció. Solicita uno nuevo.',
  verification_limit: 'Espera antes de reenviar. Si persiste, solicita ayuda desde tu expediente.',
  organization_required: 'Falta confirmar la organización que representa el solicitante.',
  scope_conflict: 'Este perfil ya tiene una relación o solicitud activa. Revisa el conflicto de representación.',
  evidence_required: 'Falta comprobar el contacto oficial o aceptar evidencia documental.',
  scope_confirmation_required: 'Confirma el alcance y registra la justificación de la aprobación.',
  contact_source_required: 'Registra la fuente HTTPS y cómo acredita el correo oficial.',
  corporate_contact_required: 'Usa la vía documental cuando el correo sea de un servicio personal.',
  request_limit: 'Ya tienes varias solicitudes abiertas. Continúa las existentes.',
  reason_required: 'Escribe un motivo que explique la decisión.',
};

export async function applicationResponse(
  request: Request, rpc: RpcClient, actor: { id: string; aal: string }, isAdmin: boolean,
  reply: (data: unknown, status: number) => Response,
  readBody: (request: Request) => Promise<Record<string, unknown> | Response>,
): Promise<Response> {
  const url = new URL(request.url);
  const prefix = isAdmin ? '/api/v1/admin/provider-applications' : '/api/v1/provider/applications';
  const parts = url.pathname.slice(prefix.length).split('/').filter(Boolean);
  const collectionReads = new Set(isAdmin ? ['organizations', 'privacy_list'] : ['targets', 'privacy_list', 'profiles', 'changes']);
  let id: string | null = null;
  let action: string;
  let data: Record<string, unknown> = {};
  if (request.method === 'GET') {
    if (!parts.length) action = 'list';
    else if (parts.length === 1 && collectionReads.has(parts[0])) action = parts[0];
    else if (parts.length === 1) { action = 'detail'; id = parts[0]; }
    else return reply({ error: { code: 'not_found' } }, 404);
    data = Object.fromEntries(['q', 'status', 'days', 'offset'].map(key => [key, url.searchParams.get(key) ?? '']));
    if (!data.offset) data.offset = 0;
    if (String(data.q).length > 160 || !/^\d{0,5}$/.test(String(data.offset)) || !/^(|15|30)$/.test(String(data.days)))
      return reply({ error: { code: 'invalid_request' } }, 400);
  } else if (request.method === 'POST') {
    if (!parts.length && !isAdmin) action = 'create';
    else if (parts.length === 1 && parts[0] === 'privacy_request' && !isAdmin) action = parts[0];
    else if (parts.length === 2) { id = parts[0]; action = parts[1]; }
    else return reply({ error: { code: 'not_found' } }, 404);
    if (!(isAdmin ? adminActions : providerActions).has(action)) return reply({ error: { code: 'forbidden' } }, 403);
    const body = await readBody(request);
    if (body instanceof Response) return body;
    data = body;
    if (id && action !== 'verify' && (!Number.isSafeInteger(data.revision) || Number(data.revision) < 0))
      return reply({ error: { code: 'invalid_request', message: 'Falta la versión de la solicitud.' } }, 400);
    if (action === 'verify' && (typeof data.code !== 'string' || !/^[a-f0-9]{64}$/.test(data.code)))
      return reply({ error: { code: 'verification_expired', message: messages.verification_expired } }, 400);
    if (action === 'privacy_request'
      && (typeof data.kind !== 'string' || !['access', 'rectification', 'cancellation', 'opposition', 'withdrawal'].includes(data.kind)
        || typeof data.message !== 'string' || data.message.trim().length < 1 || data.message.length > 2000)) {
      return reply({ error: { code: 'invalid_request', message: 'Indica el tipo y el motivo de tu solicitud.' } }, 400);
    }
  } else return reply({ error: { code: 'method_not_allowed' } }, 405);
  if (id && !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) return reply({ error: { code: 'invalid_id' } }, 400);
  const result = await rpc.call<Record<string, unknown>>('api_server_provider_application', {
    p_actor_user_id: actor.id, p_actor_aal: actor.aal, p_is_admin: isAdmin,
    p_action: action, p_id: id, p_data: data,
  }, { admin: true });
  if (typeof result.error === 'string') {
    const code = result.error;
    const status = code === 'not_found' ? 404
      : code === 'intake_disabled' ? 503
      : ['invalid_request', 'consent_required', 'account_email_required', 'verification_expired'].includes(code) ? 400
      : 409;
    return reply({ error: { code, message: messages[code] ?? 'Revisa los datos de la solicitud.' } }, status);
  }
  return reply(result, action === 'create' || action === 'privacy_request' ? 201 : 200);
}
