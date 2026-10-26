import {z} from 'zod';
const version=z.number().int().min(0).max(2147483646);
const reason=z.string().trim().min(10).max(1000),evidence=z.string().trim().min(1).max(200);
export const productionSetupInput=z.object({tenant_id:z.uuid(),version,
 price_authority:z.literal('plockivo'),credit_authority:z.literal('merchant-manual'),inventory_authority:z.literal('plockivo'),billing_authority:z.literal('manual-export'),
 activate_production:z.boolean(),sales_enabled:z.boolean(),reason,evidence_reference:evidence}).strict();
export const productionCatalogInput=z.object({tenant_id:z.uuid(),item_id:z.uuid(),source_version:z.number().int().positive().max(2147483646),customer_account_id:z.uuid(),version}).strict();
export const productionStockInput=z.object({tenant_id:z.uuid(),store_id:z.uuid(),product_id:z.uuid(),version,
 on_hand:z.string().regex(/^(?:0|[1-9]\d{0,11})(?:\.\d{1,6})?$/),reason,evidence_reference:evidence}).strict();
export const productionStoreInput=z.object({tenant_id:z.uuid(),id:z.uuid().nullable(),version,name:z.string().trim().min(1).max(160),code:z.string().trim().min(1).max(80),sales_paused:z.boolean()}).strict().refine(v=>v.id!==null||v.version===0);
export const productionProjectInput=z.object({tenant_id:z.uuid(),id:z.uuid().nullable(),version,customer_account_id:z.uuid(),name:z.string().trim().min(1).max(160),budget_minor:z.string().regex(/^(0|[1-9]\d{0,11})$/),active:z.boolean()}).strict().refine(v=>v.id!==null||v.version===0);
