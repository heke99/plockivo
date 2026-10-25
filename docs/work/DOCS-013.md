# DOCS-013 — läsbar testköpbekräftelse

2026-10-25. Del 4 före domänaktivering. Ingen faktura, följesedel, PDF, utskick eller fysisk utlämning skapas av läsflödet.

## Implementation

GET /v1/purchase-intents/{id}/confirmation läser det befintliga worker-genererade dokumentet. API verifierar personidentitet och kvot, RPC public.get_order_confirmation använder SECURITY INVOKER med fast tom search_path, explicit MFA och befintlig orders/documents-RLS. Anonym execute nekas. Inget service-anrop eller ny permission introduceras. Saknad eller otillåten order ger samma NOT_FOUND. Ingen köad jobbstatus eller annan handlares uppgifter lämnas ut.

Behörig order utan genererat dokument ger status pending och document null. Genererat dokument ger ready och fryst content, document-id, tid, mallversion och befintlig hash. Hashen är befintlig teknisk kontrollsumma, ingen e-signatur. GET skapar inga jobb, dokument eller auditposter.

Webben visar tydlig väntan, fel med retry och sparad snapshot med säljare, köpare, referens, rader och total. React-textescaping; inga HTML-injektioner eller externa filer. Vid ny intent, omladdning av dokument eller fel rensas gammalt dokument. Begäran avbryts vid unmount. Testmärkning skiljer dokumentet från faktura/följesedel/utlämningsrätt. Belopp formateras med BigInt.

## Verifiering

Migration 20261025224913_order_confirmation_read tillämpad i syntetiska Supabase cqznytuyutrqenbbyczc och filnamn synkat med serverhistorik. tests/confirmations.sql terminal PASS med riktiga authenticated/service_role/anon-kontexter: eget testköp -> pending -> worker -> ready, exakt snapshot och 25000 öre, upprepad läsning utan effekt, en synlig handling, korshandlare nekas, återkallat mandat nekas, direkt document-RLS nekas och anonym execute nekas. Hela provet rollback; inga persistenta fixtures skapade. Testet ingår i run-database.mjs.

API typkontroll och 12 befintliga enhetstester PASS. OpenAPI är uppdaterat och båda genererade klientartefakterna samt kontraktslåsets SHA är synkade.

Fokuserad Chromium-körning tests/e2e/order-confirmation.cjs PASS på sammanförda webbbygget: pending visar inget fabricerat dokument, ready visar snapshot och testmärkning, scriptliknande text visas som text, 404 rensar tidigare dokument, 390/768/1440px utan overflow och inga pageerrors. Mobilskärmbild visuellt granskad. Detta UI-prov använder intercepted API och är inte Auth-/RLS-bevis; SQL-provet ovan ger separat verkligt databasbevis. Ingen driftsatt webbläsar-PASS påstås av denna delagent.

## Kvarstående

Verklig ERP-bekräftelse, affärsgodkänd dokumentmall/PDF, notifieringsleverans, nedladdnings-/arkivpolicy och pilotens utlämning/retur/fakturering återstår. Inga verkliga köp öppnas. Parent äger sammanförd slutbuild, publicering och driftsatt kontroll.
