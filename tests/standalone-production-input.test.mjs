import {test} from 'node:test';import assert from 'node:assert/strict';
import {productionSetupInput,productionCatalogInput,productionStockInput} from '../src/lib/standalone-production-input.ts';
const id='a0000000-0000-4000-8000-000000000001';
const setup={tenant_id:id,version:0,price_authority:'plockivo',credit_authority:'merchant-manual',inventory_authority:'plockivo',billing_authority:'manual-export',activate_production:true,sales_enabled:false,reason:'Ett uttryckligt manuellt beslut',evidence_reference:'Beslut 123'};
test('production setup requires explicit authorities, activation and sales choice',()=>{
 assert(productionSetupInput.safeParse(setup).success);
 for(const patch of [{price_authority:'erp'},{billing_authority:'invoice'},{activate_production:undefined},{sales_enabled:undefined},{reason:'kort'},{evidence_reference:''},{mode:'test'},{version:-1}])assert.equal(productionSetupInput.safeParse({...setup,...patch}).success,false);
});
test('production catalog publishes a versioned source for one explicit account',()=>{
 const b={tenant_id:id,item_id:id,source_version:1,customer_account_id:id,version:0};assert(productionCatalogInput.safeParse(b).success);
 for(const patch of [{source_version:0},{version:1.2},{unit_price_minor:'1'},{product_id:id},{customer_account_id:null}])assert.equal(productionCatalogInput.safeParse({...b,...patch}).success,false);
});
test('production stock adjustments use absolute exact quantities without touching reserved',()=>{
 const b={tenant_id:id,store_id:id,product_id:id,version:0,on_hand:'999999999999.123456',reason:setup.reason,evidence_reference:setup.evidence_reference};assert(productionStockInput.safeParse(b).success);
 for(const on_hand of [-1,'-1','1e3','1,5','01','1000000000000','1.1234567'])assert.equal(productionStockInput.safeParse({...b,on_hand}).success,false);
 for(const patch of [{reserved:'0'},{delta:'1'},{actor_id:id},{version:-1}])assert.equal(productionStockInput.safeParse({...b,...patch}).success,false);
});
import {productionStoreInput,productionProjectInput} from '../src/lib/standalone-production-input.ts';
test('production stores and projects require explicit status and immutable context fields',()=>{
 const store={tenant_id:id,id:null,version:0,name:'Butiken',code:'S1',sales_paused:true};assert(productionStoreInput.safeParse(store).success);assert.equal(productionStoreInput.safeParse({...store,version:1}).success,false);assert.equal(productionStoreInput.safeParse({...store,sales_paused:undefined}).success,false);
 const project={tenant_id:id,id:null,version:0,customer_account_id:id,name:'Projekt',budget_minor:'10000',active:true};assert(productionProjectInput.safeParse(project).success);for(const patch of [{committed_minor:'0'},{budget_minor:1},{customer_account_id:null},{version:1}])assert.equal(productionProjectInput.safeParse({...project,...patch}).success,false);
});
