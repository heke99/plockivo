/** Versioned release capabilities, never a live tenant check or sales activation. */
export function integrationReadiness(){return {schema_version:2,profile:'standalone_configuration',can_activate_sales:false,scope:'release_capabilities',capabilities:[
 {id:'catalog_price',label:'Sortiment och kundpris',status:'configuration_available',proof:'Fristående artikel- och prisinställningar finns. Publicera och verifiera butikens sortiment, förpackningar, kundpris och avrundning före användning. ERP-anslutning kräver separat verifiering.'},
 {id:'credit_reservation',label:'Kreditreservation',status:'conditional_standalone',proof:'Fristående kreditgränser och köpbegränsningar kan konfigureras. Kreditauktoritet, aktuella exponeringar och samtidiga köp i samtliga försäljningskanaler måste verifieras för handlaren.'},
 {id:'inventory_reservation',label:'Lager och reservation',status:'conditional_standalone',proof:'Fristående lagerinställningar finns. Startsaldo, lagerauktoritet, reservation, avslut och kompensation måste verifieras innan lagerlöften ges.'},
 {id:'invoice_creation',label:'Faktureringsunderlag',status:'manual_export',proof:'Manuellt exportunderlag är inte en utfärdad eller bokförd faktura. Fakturanummer, mottagande ekonomisystem och avstämning kräver separat verifiering.'},
 {id:'reconciliation',label:'Extern avstämning',status:'not_connected',proof:'Ingen generell extern ekonomianslutning är verifierad. Prova förlorat svar efter extern effekt och uppslag via stabil affärsidentitet för varje vald integration.'},
 {id:'email_delivery',label:'E-postleverans',status:'verification_required',proof:'SMTP och mallar kan konfigureras. Extern mottagning, studs och leverans av varje meddelandetyp måste provas. En sparad inställning bevisar inte leverans.'}
 ]};}
