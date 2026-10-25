import {z} from 'zod';
// Hostnames only: no URLs, ports, wildcards, IPs, credentials or local hosts.
export const hostnameInput=z.string().trim().toLowerCase().max(253).regex(/^(?=.{4,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/).refine(h=>!h.endsWith('.localhost')&&!h.endsWith('.local')&&!h.endsWith('.internal')&&h!=='plockivo.com'&&!h.endsWith('.plockivo.com'),'Ange en egen publik domän.');
export const domainRequestInput=z.object({tenant_id:z.uuid(),hostname:hostnameInput}).strict();
export const domainRemoveInput=z.object({tenant_id:z.uuid(),version:z.number().int().positive()}).strict();
