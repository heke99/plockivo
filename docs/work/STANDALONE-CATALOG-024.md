# STANDALONE-CATALOG-024 — fristående förberedelseregister

Separat private.standalone_catalog_items lagrar handlarens artikel- och grundprisdata. Befintliga synthetic products/test_prices och checkout ändras inte. Listan är begränsad till200; självskanningflagga innebär inte att checkout är aktiverad. GET/POST /standalone-catalog med exact minor-unit strings, positiva sexdecimaliga mängdsteg/förpackningar, versionskontroll och idempotens. Full merchant_admin MFA krävs. SKU och streckkod är unika per handlare. Audit, data och command sparas tillsammans under ett handlarlås. Kundspecifika priser, live kredit/lager och produktion är inte aktiverade.

Pending migration20261026010210_standalone_catalog.sql. apply_migration REJECTED av automatisk granskning: persistent shared schema/role/functions/grants behöver exakt migrationsgodkännande; arkitekturval räckte inte. Ingen retry/omväg. STANDALONE_CATALOG_ADMIN_ENABLED=false tills migration och SQL-rolltest godkänts. tests/standalone-catalog.sql är förberett men EJ KÖRT; inget live SQL-PASS påstås. Transporttest och API typecheck/25 tester PASS. Parent äger release.

Slutlig API npm run verify PASS exit0: standard, typecheck,25 tester, produktionsbygge. Inga persistenta katalogtestdata skapade. Genererade klienter och kontraktslås synkade med båda nya adminresurserna.

Godkänd2026-10-26: migration20261026154612 tillämpad, riktig SQL-rollmatris version/replay/unikhet/exakta belopp/tenant PASS med rollback. Gate STANDALONE_CATALOG_ADMIN_ENABLED=true konfigurerad inför nästa deployment. Ingen verklig checkout aktiverad.
