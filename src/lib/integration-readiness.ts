/** Release capability inventory, not a customer assertion or production switch. */
export function integrationReadiness(){return {schema_version:1,profile:'synthetic-test',production_sales_enabled:false,scope:'release_capabilities',capabilities:[
 {id:'catalog_price',label:'Sortiment och kundpris',status:'synthetic_only',proof:'Verifiera artikel, förpackning, rabattordning och avrundning i fristående profil eller vald ERP-adapter. Explicit testpublicering är en fryst kopia.'},
 {id:'credit_reservation',label:'Kreditreservation',status:'synthetic_only',proof:'Namnge kreditauktoritet och prova samtidiga köp i samtliga försäljningskanaler.'},
 {id:'inventory_reservation',label:'Lagerreservation',status:'not_connected',proof:'Verifiera lagerauktoritet, reservation och kompensation innan lagerlöften ges.'},
 {id:'invoice_creation',label:'Fakturering',status:'not_connected',proof:'Verifiera fakturerbar händelse, radallokering och idempotens.'},
 {id:'reconciliation',label:'Extern avstämning',status:'not_connected',proof:'Prova förlorat svar efter extern effekt och uppslag via stabil affärsidentitet.'},
 {id:'email_delivery',label:'Affärsmeddelanden',status:'manual_review',proof:'Verifiera avsändare, leverans, studs och osäkert leverantörsutfall. Auth-utskick har separat spärr.'}
 ]};}
