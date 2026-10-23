-- Isolated synthetic fixture only. Load tests/fixtures.sql once, then run in the same transaction.
-- This creates one real TEST order through the same checked domain functions used by the API.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005","role":"authenticated"}',true);
do $$declare i jsonb;o jsonb;begin
 i:=public.prepare_purchase('{"tenant_id":"00000000-0000-4000-8000-000000000001","customer_account_id":"00000000-0000-4000-8000-000000000002","store_id":"00000000-0000-4000-8000-000000000003","project_id":"00000000-0000-4000-8000-000000000004","reference":"WORKER-004","lines":[{"product_id":"00000000-0000-4000-8000-000000000006","quantity":"2"}]}',gen_random_uuid()::text,gen_random_uuid());
 o:=public.confirm_purchase((i->>'id')::uuid,jsonb_build_object('version',1,'quote_hash',i->>'quote_hash'),gen_random_uuid()::text,gen_random_uuid());
end$$;
reset role;
