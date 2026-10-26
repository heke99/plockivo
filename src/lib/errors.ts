export const messages: Record<string,string> = {
  INVITATION_INVALID:'Inbjudan kan inte visas för detta konto. Kontrollera länken och din inloggning.', INVITATION_UNAVAILABLE:'Inbjudan har gått ut, återkallats eller är inte längre tillgänglig.', INVITATION_FINAL:'Inbjudan är redan accepterad. Medlemskapet hanteras separat.', MFA_REQUIRED:'Bekräfta din inloggning med en engångskod.', AUTH_REQUIRED:'Logga in för att fortsätta.', PERMISSION_DENIED:'Du saknar behörighet för den här handlingen.',
  CUSTOMER_EXISTS:'Kunden finns redan hos handlaren.', CATALOG_DUPLICATE:'Artikelnummer eller streckkod används redan hos handlaren.',
  NOT_FOUND:'Underlaget kunde inte hittas.', MEMBERSHIP_INACTIVE:'Ditt inköpsmandat är inte aktivt.',
  VALIDATION_ERROR:'Kontrollera uppgifterna och försök igen.', VERSION_CONFLICT:'Underlaget har ändrats. Hämta den senaste versionen.',
  IDEMPOTENCY_CONFLICT:'Begäran har redan använts med ett annat innehåll.', CREDIT_UNAVAILABLE:'Kreditutrymmet räcker inte eller kontot är spärrat.',
  APPROVAL_REQUIRED:'Köpet kräver attest innan du kan bekräfta.', PRICE_CHANGED:'Prisunderlaget har ändrats eller gått ut. Förbered köpet igen.',
  SALES_PAUSED:'Nya köp är pausade.', INTEGRATION_NOT_READY:'Handlarens verkliga integration är ännu inte aktiverad.',
  BUDGET_EXCEEDED:'Köpet överskrider ditt mandat eller projektets budget.', INTERNAL_ERROR:'Ett tekniskt fel uppstod. Kontrollera köpets status innan ett nytt försök.',
  QUANTITY_CONFLICT:'Mängden är redan disponerad. Hämta aktuellt underlag.', INSPECTION_REQUIRED:'Kontrollera samma rader och mottagare före testanspråket.', RETURN_QUANTITY_EXCEEDED:'Returmängden överstiger bekräftat utlämnad mängd.',
  RATE_LIMITED:'För många anrop. Försök igen om en stund.',
};
export function failure(code: string, correlationId: string, status = 400) {
 return Response.json({error:{code,message:messages[code]??messages.INTERNAL_ERROR,correlation_id:correlationId}}, {status,headers:{'Cache-Control':'no-store','X-Correlation-ID':correlationId}});
}

