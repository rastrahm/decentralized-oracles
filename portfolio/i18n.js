const I18N = {
  es: {
    'html.lang': 'es',
    'meta.title': 'Decentralized Oracles Push/Pull — Rolando Strahm',
    'meta.description':
      'Consumidor de precios Chainlink Push + Pyth Pull, gas (Push vs Pull) y auditoría SWC. Foundry · Solidity 0.8.24.',

    'nav.overview': 'Proyecto',
    'nav.pillars': 'Pilares',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Proceso',
    'nav.attacks': 'Ataques',
    'nav.repos': 'Repos',
    'nav.close': '← Cerrar',

    'hero.tag': '// MÓDULO 13 · PORTFOLIO WEB3',
    'hero.title': 'DECENTRALIZED<br>ORACLES',
    'hero.role': 'Chainlink Push · Pyth Pull · Foundry · Solidity 0.8.24',
    'hero.sub':
      'Consumidor resiliente de precios con validación de staleness, rounds y bounds; gas documentado (Push vs Pull) y auditoría defensiva SWC-100–136.',
    'hero.cta1': 'Ver en GitHub',
    'hero.cta2': 'Ver en GitLab',

    'ov.eyebrow': '// 01 — CONTEXTO',
    'ov.title': 'Por qué este proyecto',
    'ov.lead':
      'Los protocolos DeFi no pueden “llamar a una API” on-chain. Este módulo implementa <strong>Push (Chainlink)</strong> y <strong>Pull (Pyth)</strong> con Foundry: wrappers seguros, un <strong>PriceOracleConsumer</strong> unificado, mocks controlables, fork de ETH/USD, y cierre con <strong>gas</strong> (raw vs Push vs Pull) y <strong>SWC</strong>.',

    'pi.eyebrow': '// 02 — TRES PILARES',
    'pi.title': 'Qué entrega el módulo',
    'p1.num': '// PILAR_01',
    'p1.title': 'Push + Pull',
    'p1.desc':
      'ChainlinkPriceFeed (AggregatorV3) y PythPriceFeed (fee → update → validate → refund), orquestados por PriceOracleConsumer.',
    'p1.l1': 'Staleness · round · bounds',
    'p1.l2': 'Fee exacto + refund al caller',
    'p1.l3': 'Escala 8 → 18 decimals',
    'p2.num': '// PILAR_02',
    'p2.title': 'Optimización de gas',
    'p2.desc':
      'Immutables, library de validación, custom errors y fee exacto en el consumer; baseline raw vs Push vs Pull en snapshot.',
    'p2.l1': 'Raw ~16k · Push ~20k · Pull ~170k',
    'p2.l2': 'Config immutable + via_ir',
    'p2.l3': 'Gas report + .gas-snapshot',
    'p3.num': '// PILAR_03',
    'p3.title': 'Verificación SWC',
    'p3.desc':
      'Matriz SWC-100–136 con foco en staleness, refunds ETH, reentrancy en Pull y precios inválidos.',
    'p3.l1': '31 mitigados / N/A · 5 informativos',
    'p3.l2': '0 vulnerabilidades explotables',
    'p3.l3': 'E2E + fork + fuzz 1000',

    'gas.eyebrow': '// 03 — OPTIMIZACIÓN DE GAS',
    'gas.title': 'Push barato, Pull cara — medido',
    'gas.lead':
      'Fase 6: cada técnica está en <code>doc/GAS.md</code> con su <strong>tradeoff</strong>. Validar Push añade poco sobre la lectura cruda; <strong>Pull</strong> domina por <code>updatePriceFeeds</code> (escritura + fee). Baseline Foundry del snapshot.',
    'gas.bth1': 'Path',
    'gas.bth2': 'Gas (snapshot)',
    'gas.b1a': 'Raw latestRoundData',
    'gas.b2a': 'Push getValidatedPrice',
    'gas.b3a': 'Consumer Push / Scaled18',
    'gas.b4a': 'Pull updateAndGetPrice',
    'gas.b5a': 'Consumer getPullPrice',
    'gas.th1': 'Optimización',
    'gas.th2': 'Tradeoff / efecto',
    'gas.r1a': 'aggregator / pyth / bounds / delays immutable',
    'gas.r1b': 'Sin SLOAD de config en hot path; retune = redeploy',
    'gas.r2a': 'OracleValidationLib (library)',
    'gas.r2b': 'Reuso Push/Pull + inlining con optimizer',
    'gas.r3a': 'Custom errors (OracleErrors)',
    'gas.r3b': 'Reverts más baratos que require con strings',
    'gas.r4a': 'Consumer paga fee exacto al Pull',
    'gas.r4b': 'Evita refund interno del feed; exceso al caller',
    'gas.r5a': 'calldata en updateData',
    'gas.r5b': 'Menos copias memory en paths Pull',
    'gas.r6a': 'PriceScalerLib solo en consumer',
    'gas.r6b': 'Feeds reportan decimals nativos; scale bajo demanda',
    'gas.r7a': 'optimizer_runs = 10_000 + via_ir',
    'gas.r7b': 'Inlining agresivo; deploy un poco más caro a cambio de runtime',

    'swc.eyebrow': '// 04 — VERIFICACIÓN SWC',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      'Matriz completa <strong>SWC-100 → SWC-136</strong> contra consumer, feeds y libs. Informe en <code>doc/SWC-AUDIT.md</code>. Conclusión: <strong>0 vulnerabilidades explotables</strong>; precios stale / inválidos / fee insuficiente revierten con custom errors.',
    'swc.s1': 'Mitigados / N/A',
    'swc.s2': 'Informativos (diseño)',
    'swc.s3': 'Vulnerables',
    'swc.th1': 'SWC clave',
    'swc.th2': 'Mitigación en el contrato',
    'swc.r103': 'Floating pragma: pragma solidity 0.8.24 fijo',
    'swc.r105': 'Refunds checan ok → EthTransferFailed; sin withdraw libre de ETH',
    'swc.r107': 'Pull: update → validate → refund; consumer envía fee exacto',
    'swc.r111': 'Sin transfer/send; solo .call{value} para fee/refund',
    'swc.r123': 'Custom errors + unit / e2e / fuzz / fork',
    'swc.r101': 'Solidity 0.8.24 + guarda overflow en PriceScalerLib',
    'swc.info': 'INFORMATIVO',
    'swc.i1t': 'block.timestamp (staleness)',
    'swc.i1d':
      'Push/Pull comparan updatedAt/publishTime contra block.timestamp. Estándar de oráculos; usar maxDelay/maxAge conservadores.',
    'swc.i2t': 'Orden / relayers',
    'swc.i2d':
      'En Pull, quien aporta updateData elige el momento. No es bypass de validación: riesgo de dominio DeFi (liquidaciones), no del wrapper.',

    'pr.eyebrow': '// 05 — PROCESO',
    'pr.title': 'Fases 0–6 cerradas',
    'pr.lead':
      'Desarrollo por gates: setup Foundry + deps, libs/errors, mocks, Chainlink Push, Pyth Pull, consumer/fork/fuzz y deploy + gas + SWC.',
    'ph.0': 'Bootstrap Foundry + Chainlink/Pyth',
    'ph.12': 'Libs + mocks',
    'ph.34': 'Chainlink Push + Pyth Pull',
    'ph.5': 'Consumer · e2e · fork · fuzz',
    'ph.6': 'Deploy · gas · SWC',
    'st.1': 'Fases',
    'st.2': 'Tests PASS',
    'st.3': 'SWC críticos',
    'st.4': 'Fuzz runs',
    'term.label': 'rolando@strahm:~/13-decentralized-oracles',
    'term.1': 'forge test --summary',
    'term.2': '[PASS] suite · 102 passed · 3 skipped',
    'term.3': 'cat doc/SWC-AUDIT.md | head',
    'term.4': 'Vulnerable: 0 · Informativos: 5 · Mitigados/N/A: 31',
    'term.5': 'echo status',
    'term.6': 'MODULE_13_CLOSED · PUSH_PULL_V1',

    'at.eyebrow': '// 06 — CAMPAÑAS DE ATAQUE',
    'at.title': 'Defensivo, no ofensivo',
    'at.lead':
      'Suite e2e + fuzz: el “éxito” del ataque es que revierta. Sin PoCs de exploit — StalePriceFeed, OracleRoundIncomplete, InvalidOraclePrice e InsufficientFee.',
    'cA.t': 'Stale price',
    'cA.d': 'updatedAt / publishTime viejos → StalePriceFeed.',
    'cB.t': 'Incomplete round',
    'cB.d': 'answeredInRound < roundId → OracleRoundIncomplete.',
    'cC.t': 'Bad price',
    'cC.d': 'Cero, negativo o fuera de bounds → InvalidOraclePrice.',
    'cD.t': 'Insufficient fee',
    'cD.d': 'Pull sin ETH suficiente → InsufficientFee.',
    'cE.t': 'Fuzz bounds',
    'cE.d': 'Answers, delays y scale 8↔18 sin panics inesperados.',

    're.eyebrow': '// 07 — CÓDIGO ABIERTO',
    're.title': 'Repositorios',
    're.lead':
      'El mismo código está en GitHub y GitLab: feeds, consumer, tests, gas, auditoría SWC y diagramas.',
    're.cta': 'Contactar',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — Decentralized Oracles · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · ALL_SYSTEMS_OPERATIONAL',
  },

  en: {
    'html.lang': 'en',
    'meta.title': 'Decentralized Oracles Push/Pull — Rolando Strahm',
    'meta.description':
      'Chainlink Push + Pyth Pull price consumer, gas (Push vs Pull), and SWC audit. Foundry · Solidity 0.8.24.',

    'nav.overview': 'Project',
    'nav.pillars': 'Pillars',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Process',
    'nav.attacks': 'Attacks',
    'nav.repos': 'Repos',
    'nav.close': '← Close',

    'hero.tag': '// MODULE 13 · WEB3 PORTFOLIO',
    'hero.title': 'DECENTRALIZED<br>ORACLES',
    'hero.role': 'Chainlink Push · Pyth Pull · Foundry · Solidity 0.8.24',
    'hero.sub':
      'Resilient price consumer with staleness, round, and bounds checks; documented gas (Push vs Pull) and defensive SWC-100–136 audit.',
    'hero.cta1': 'View on GitHub',
    'hero.cta2': 'View on GitLab',

    'ov.eyebrow': '// 01 — CONTEXT',
    'ov.title': 'Why this project',
    'ov.lead':
      'DeFi protocols cannot simply “call an API” on-chain. This module implements <strong>Push (Chainlink)</strong> and <strong>Pull (Pyth)</strong> with Foundry: safe wrappers, a unified <strong>PriceOracleConsumer</strong>, controllable mocks, an ETH/USD fork, and a close-out with <strong>gas</strong> (raw vs Push vs Pull) and <strong>SWC</strong>.',

    'pi.eyebrow': '// 02 — THREE PILLARS',
    'pi.title': 'What the module ships',
    'p1.num': '// PILLAR_01',
    'p1.title': 'Push + Pull',
    'p1.desc':
      'ChainlinkPriceFeed (AggregatorV3) and PythPriceFeed (fee → update → validate → refund), orchestrated by PriceOracleConsumer.',
    'p1.l1': 'Staleness · round · bounds',
    'p1.l2': 'Exact fee + refund to caller',
    'p1.l3': 'Scale 8 → 18 decimals',
    'p2.num': '// PILLAR_02',
    'p2.title': 'Gas optimization',
    'p2.desc':
      'Immutables, validation library, custom errors, and exact fee in the consumer; raw vs Push vs Pull baseline in the snapshot.',
    'p2.l1': 'Raw ~16k · Push ~20k · Pull ~170k',
    'p2.l2': 'Immutable config + via_ir',
    'p2.l3': 'Gas report + .gas-snapshot',
    'p3.num': '// PILLAR_03',
    'p3.title': 'SWC verification',
    'p3.desc':
      'SWC-100–136 matrix focused on staleness, ETH refunds, Pull reentrancy, and invalid prices.',
    'p3.l1': '31 mitigated / N/A · 5 informative',
    'p3.l2': '0 exploitable vulnerabilities',
    'p3.l3': 'E2E + fork + fuzz 1000',

    'gas.eyebrow': '// 03 — GAS OPTIMIZATION',
    'gas.title': 'Cheap Push, expensive Pull — measured',
    'gas.lead':
      'Phase 6: every technique lives in <code>doc/GAS.md</code> with its <strong>tradeoff</strong>. Push validation adds little over a raw read; <strong>Pull</strong> dominates via <code>updatePriceFeeds</code> (write + fee). Foundry snapshot baseline.',
    'gas.bth1': 'Path',
    'gas.bth2': 'Gas (snapshot)',
    'gas.b1a': 'Raw latestRoundData',
    'gas.b2a': 'Push getValidatedPrice',
    'gas.b3a': 'Consumer Push / Scaled18',
    'gas.b4a': 'Pull updateAndGetPrice',
    'gas.b5a': 'Consumer getPullPrice',
    'gas.th1': 'Optimization',
    'gas.th2': 'Tradeoff / effect',
    'gas.r1a': 'aggregator / pyth / bounds / delays immutable',
    'gas.r1b': 'No config SLOAD on the hot path; retune = redeploy',
    'gas.r2a': 'OracleValidationLib (library)',
    'gas.r2b': 'Shared Push/Pull logic + optimizer inlining',
    'gas.r3a': 'Custom errors (OracleErrors)',
    'gas.r3b': 'Cheaper reverts than require with strings',
    'gas.r4a': 'Consumer pays exact Pull fee',
    'gas.r4b': 'Skips inner feed refund; excess returned to caller',
    'gas.r5a': 'calldata for updateData',
    'gas.r5b': 'Fewer memory copies on Pull paths',
    'gas.r6a': 'PriceScalerLib only in the consumer',
    'gas.r6b': 'Feeds keep native decimals; scale on demand',
    'gas.r7a': 'optimizer_runs = 10_000 + via_ir',
    'gas.r7b': 'Aggressive inlining; slightly costlier deploy for cheaper runtime',

    'swc.eyebrow': '// 04 — SWC VERIFICATION',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      'Full <strong>SWC-100 → SWC-136</strong> matrix against the consumer, feeds, and libs. Report in <code>doc/SWC-AUDIT.md</code>. Conclusion: <strong>0 exploitable vulnerabilities</strong>; stale / invalid prices and underpaid fees revert with custom errors.',
    'swc.s1': 'Mitigated / N/A',
    'swc.s2': 'Informative (design)',
    'swc.s3': 'Vulnerable',
    'swc.th1': 'Key SWC',
    'swc.th2': 'Mitigation in the contracts',
    'swc.r103': 'Floating pragma: fixed pragma solidity 0.8.24',
    'swc.r105': 'Refunds check ok → EthTransferFailed; no free ETH withdrawal',
    'swc.r107': 'Pull: update → validate → refund; consumer sends exact fee',
    'swc.r111': 'No transfer/send; only .call{value} for fee/refund',
    'swc.r123': 'Custom errors + unit / e2e / fuzz / fork',
    'swc.r101': 'Solidity 0.8.24 + overflow guard in PriceScalerLib',
    'swc.info': 'INFORMATIVE',
    'swc.i1t': 'block.timestamp (staleness)',
    'swc.i1d':
      'Push/Pull compare updatedAt/publishTime to block.timestamp. Oracle standard; keep maxDelay/maxAge conservative.',
    'swc.i2t': 'Ordering / relayers',
    'swc.i2d':
      'On Pull, whoever supplies updateData chooses timing. Not a validation bypass: DeFi-domain risk (liquidations), not the wrapper.',

    'pr.eyebrow': '// 05 — PROCESS',
    'pr.title': 'Phases 0–6 closed',
    'pr.lead':
      'Gate-driven build: Foundry + deps, libs/errors, mocks, Chainlink Push, Pyth Pull, consumer/fork/fuzz, then deploy + gas + SWC.',
    'ph.0': 'Bootstrap Foundry + Chainlink/Pyth',
    'ph.12': 'Libs + mocks',
    'ph.34': 'Chainlink Push + Pyth Pull',
    'ph.5': 'Consumer · e2e · fork · fuzz',
    'ph.6': 'Deploy · gas · SWC',
    'st.1': 'Phases',
    'st.2': 'Tests PASS',
    'st.3': 'Critical SWCs',
    'st.4': 'Fuzz runs',
    'term.label': 'rolando@strahm:~/13-decentralized-oracles',
    'term.1': 'forge test --summary',
    'term.2': '[PASS] suite · 102 passed · 3 skipped',
    'term.3': 'cat doc/SWC-AUDIT.md | head',
    'term.4': 'Vulnerable: 0 · Informative: 5 · Mitigated/N/A: 31',
    'term.5': 'echo status',
    'term.6': 'MODULE_13_CLOSED · PUSH_PULL_V1',

    'at.eyebrow': '// 06 — ATTACK CAMPAIGNS',
    'at.title': 'Defensive, not offensive',
    'at.lead':
      'E2E + fuzz suite: a successful “attack” is a revert. No exploit PoCs — StalePriceFeed, OracleRoundIncomplete, InvalidOraclePrice, and InsufficientFee.',
    'cA.t': 'Stale price',
    'cA.d': 'Old updatedAt / publishTime → StalePriceFeed.',
    'cB.t': 'Incomplete round',
    'cB.d': 'answeredInRound < roundId → OracleRoundIncomplete.',
    'cC.t': 'Bad price',
    'cC.d': 'Zero, negative, or out of bounds → InvalidOraclePrice.',
    'cD.t': 'Insufficient fee',
    'cD.d': 'Pull without enough ETH → InsufficientFee.',
    'cE.t': 'Fuzz bounds',
    'cE.d': 'Answers, delays, and 8↔18 scale without unexpected panics.',

    're.eyebrow': '// 07 — OPEN SOURCE',
    're.title': 'Repositories',
    're.lead':
      'The same codebase is on GitHub and GitLab: feeds, consumer, tests, gas, SWC audit, and diagrams.',
    're.cta': 'Contact',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — Decentralized Oracles · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · ALL_SYSTEMS_OPERATIONAL',
  },
};

function setLanguage(lang) {
  const dict = I18N[lang] || I18N.es;
  document.documentElement.lang = dict['html.lang'];
  document.title = dict['meta.title'];

  const metaDesc = document.querySelector('meta[name="description"]');
  if (metaDesc && dict['meta.description']) {
    metaDesc.setAttribute('content', dict['meta.description']);
  }

  document.querySelectorAll('[data-i18n]').forEach((el) => {
    const key = el.getAttribute('data-i18n');
    const val = dict[key];
    if (val == null) return;
    if (el.hasAttribute('data-i18n-html')) el.innerHTML = val;
    else el.textContent = val;
  });

  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.classList.toggle('active', btn.dataset.lang === lang);
  });

  localStorage.setItem('oracle-portfolio-lang', lang);

  const url = new URL(window.location.href);
  url.searchParams.set('lang', lang);
  history.replaceState(null, '', url);
}

function initI18n() {
  const params = new URLSearchParams(window.location.search);
  const fromQuery = params.get('lang');
  const saved = localStorage.getItem('oracle-portfolio-lang');
  const preferred =
    (fromQuery === 'en' || fromQuery === 'es' ? fromQuery : null) ||
    saved ||
    (navigator.language?.startsWith('en') ? 'en' : 'es');

  setLanguage(preferred);

  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.addEventListener('click', () => setLanguage(btn.dataset.lang));
  });
}

document.addEventListener('DOMContentLoaded', initI18n);
