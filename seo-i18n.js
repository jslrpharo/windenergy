/**
 * seo-i18n.js — Lightweight inline i18n engine for ACMSL SEO topic pages.
 * Usage:
 *   1) Include this script in <head> of each SEO page.
 *   2) Add data-i18n="key" (textContent) or data-i18n-html="key" (innerHTML) to translatable elements.
 *   3) Add <script id="pt" type="application/json">{ "en":{...}, "es":{...}, ... }</script> before </body>.
 *
 * Language selection priority: ?lang=XX URL param → browser language → 'en'
 */
(function () {
  'use strict';

  /* ── Common translations (shared across all SEO pages) ─────────────────── */
  var COMMON = {
    en: {
      'header.subtitle': 'ACM SL \u2014 Wind Turbine Training &amp; Engineering Tools',
      'btn.app': 'Open Interactive App',
      'btn.contact': 'Contact',
      'btn.open-in-app': 'Open in Interactive App',
      'btn.read-tutorial': 'Read the Tutorial',
      'btn.dl-free-eval': 'Download Free Evaluation',
      'btn.dl-free': 'Download (free)',
      'btn.contact-acmsl': 'Contact ACMSL',
      'breadcrumb.home': 'Home',
      'footer.home': 'Home',
      'footer.contact': 'Contact',
      'nav.1': '1. Wind Energy Concepts',
      'nav.2': '2. Wind Farms &amp; Grid',
      'nav.3': '3. Simulators',
      'nav.4': '4. Drive Train',
      'nav.5': '5. B2B Converters',
      'nav.6': '6. Data Visualisation',
      'nav.7': '7. Tutorials',
      'nav.8': '8. Maintenance',
      'nav.9': '9. Developments',
      'nav.10': '10. Articles',
      'nav.11': '11. Downloads',
      'nav.12': '12. Clients'
    },
    es: {
      'header.subtitle': 'ACM SL \u2014 Herramientas de Formaci\u00f3n e Ingenier\u00eda para Aerogeneradores',
      'btn.app': 'Abrir App Interactiva',
      'btn.contact': 'Contacto',
      'btn.open-in-app': 'Abrir en App Interactiva',
      'btn.read-tutorial': 'Leer el Tutorial',
      'btn.dl-free-eval': 'Descargar Evaluaci\u00f3n Gratuita',
      'btn.dl-free': 'Descargar (gratis)',
      'btn.contact-acmsl': 'Contactar ACMSL',
      'breadcrumb.home': 'Inicio',
      'footer.home': 'Inicio',
      'footer.contact': 'Contacto',
      'nav.1': '1. Conceptos de Energ\u00eda E\u00f3lica',
      'nav.2': '2. Parques E\u00f3licos y Red',
      'nav.3': '3. Simuladores',
      'nav.4': '4. Tren de Potencia',
      'nav.5': '5. Convertidores B2B',
      'nav.6': '6. Visualizaci\u00f3n de Datos',
      'nav.7': '7. Tutoriales',
      'nav.8': '8. Mantenimiento',
      'nav.9': '9. Desarrollos',
      'nav.10': '10. Art\u00edculos',
      'nav.11': '11. Descargas',
      'nav.12': '12. Clientes'
    },
    fr: {
      'header.subtitle': 'ACM SL \u2014 Formation et Outils d\u2019Ing\u00e9nierie pour \u00c9oliennes',
      'btn.app': 'Ouvrir l\u2019App Interactive',
      'btn.contact': 'Contact',
      'btn.open-in-app': 'Ouvrir dans l\u2019App Interactive',
      'btn.read-tutorial': 'Lire le Tutoriel',
      'btn.dl-free-eval': 'T\u00e9l\u00e9charger l\u2019\u00c9valuation Gratuite',
      'btn.dl-free': 'T\u00e9l\u00e9charger (gratuit)',
      'btn.contact-acmsl': 'Contacter ACMSL',
      'breadcrumb.home': 'Accueil',
      'footer.home': 'Accueil',
      'footer.contact': 'Contact',
      'nav.1': '1. Concepts d\u2019\u00c9nergie \u00c9olienne',
      'nav.2': '2. Parcs \u00c9oliens et R\u00e9seau',
      'nav.3': '3. Simulateurs',
      'nav.4': '4. Transmission de Puissance',
      'nav.5': '5. Convertisseurs B2B',
      'nav.6': '6. Visualisation de Donn\u00e9es',
      'nav.7': '7. Tutoriels',
      'nav.8': '8. Maintenance',
      'nav.9': '9. D\u00e9veloppements',
      'nav.10': '10. Articles',
      'nav.11': '11. T\u00e9l\u00e9chargements',
      'nav.12': '12. Clients'
    },
    de: {
      'header.subtitle': 'ACM SL \u2014 Schulungs- und Ingenieurwerkzeuge f\u00fcr Windturbinen',
      'btn.app': 'Interaktive App \u00f6ffnen',
      'btn.contact': 'Kontakt',
      'btn.open-in-app': 'In interaktiver App \u00f6ffnen',
      'btn.read-tutorial': 'Tutorial lesen',
      'btn.dl-free-eval': 'Kostenlose Testversion herunterladen',
      'btn.dl-free': 'Herunterladen (kostenlos)',
      'btn.contact-acmsl': 'ACMSL kontaktieren',
      'breadcrumb.home': 'Startseite',
      'footer.home': 'Startseite',
      'footer.contact': 'Kontakt',
      'nav.1': '1. Windenergie-Konzepte',
      'nav.2': '2. Windparks &amp; Netz',
      'nav.3': '3. Simulatoren',
      'nav.4': '4. Antriebsstrang',
      'nav.5': '5. B2B-Umrichter',
      'nav.6': '6. Datenvisualisierung',
      'nav.7': '7. Tutorials',
      'nav.8': '8. Wartung',
      'nav.9': '9. Entwicklungen',
      'nav.10': '10. Artikel',
      'nav.11': '11. Downloads',
      'nav.12': '12. Kunden'
    },
    it: {
      'header.subtitle': 'ACM SL \u2014 Formazione e Strumenti di Ingegneria per Turbine Eoliche',
      'btn.app': 'Apri App Interattiva',
      'btn.contact': 'Contatto',
      'btn.open-in-app': 'Apri nell\u2019App Interattiva',
      'btn.read-tutorial': 'Leggi il Tutorial',
      'btn.dl-free-eval': 'Scarica Valutazione Gratuita',
      'btn.dl-free': 'Scarica (gratuito)',
      'btn.contact-acmsl': 'Contatta ACMSL',
      'breadcrumb.home': 'Home',
      'footer.home': 'Home',
      'footer.contact': 'Contatto',
      'nav.1': '1. Concetti di Energia Eolica',
      'nav.2': '2. Parchi Eolici e Rete',
      'nav.3': '3. Simulatori',
      'nav.4': '4. Trasmissione di Potenza',
      'nav.5': '5. Convertitori B2B',
      'nav.6': '6. Visualizzazione Dati',
      'nav.7': '7. Tutorial',
      'nav.8': '8. Manutenzione',
      'nav.9': '9. Sviluppi',
      'nav.10': '10. Articoli',
      'nav.11': '11. Download',
      'nav.12': '12. Clienti'
    },
    pt: {
      'header.subtitle': 'ACM SL \u2014 Ferramentas de Forma\u00e7\u00e3o e Engenharia para Aerogeradores',
      'btn.app': 'Abrir App Interativa',
      'btn.contact': 'Contato',
      'btn.open-in-app': 'Abrir na App Interativa',
      'btn.read-tutorial': 'Ler o Tutorial',
      'btn.dl-free-eval': 'Baixar Avalia\u00e7\u00e3o Gratuita',
      'btn.dl-free': 'Baixar (gratuito)',
      'btn.contact-acmsl': 'Contactar ACMSL',
      'breadcrumb.home': 'In\u00edcio',
      'footer.home': 'In\u00edcio',
      'footer.contact': 'Contato',
      'nav.1': '1. Conceitos de Energia E\u00f3lica',
      'nav.2': '2. Parques E\u00f3licos e Rede',
      'nav.3': '3. Simuladores',
      'nav.4': '4. Trem de Pot\u00eancia',
      'nav.5': '5. Conversores B2B',
      'nav.6': '6. Visualiza\u00e7\u00e3o de Dados',
      'nav.7': '7. Tutoriais',
      'nav.8': '8. Manuten\u00e7\u00e3o',
      'nav.9': '9. Desenvolvimentos',
      'nav.10': '10. Artigos',
      'nav.11': '11. Downloads',
      'nav.12': '12. Clientes'
    }
  };

  var LANGS = ['en', 'es', 'fr', 'de', 'it', 'pt'];

  /* ── Language detection ─────────────────────────────────────────────────── */
  function getLang() {
    var p = new URLSearchParams(window.location.search).get('lang');
    if (p && LANGS.indexOf(p) !== -1) return p;
    var b = (navigator.language || 'en').split('-')[0];
    if (LANGS.indexOf(b) !== -1) return b;
    return 'en';
  }

  /* ── Apply translations ─────────────────────────────────────────────────── */
  function apply(lang, pageData) {
    var common = COMMON[lang] || COMMON['en'];
    var page   = (pageData && (pageData[lang] || pageData['en'])) || {};
    var d      = Object.assign({}, common, page);

    document.documentElement.lang = lang;

    /* textContent replacements */
    document.querySelectorAll('[data-i18n]').forEach(function (el) {
      var key = el.getAttribute('data-i18n');
      if (d[key] !== undefined) el.textContent = d[key];
    });

    /* innerHTML replacements (for content with embedded HTML tags) */
    document.querySelectorAll('[data-i18n-html]').forEach(function (el) {
      var key = el.getAttribute('data-i18n-html');
      if (d[key] !== undefined) el.innerHTML = d[key];
    });

    /* Browser tab title */
    if (d['_title']) document.title = d['_title'];

    /* Meta description */
    var metaD = document.querySelector('meta[name="description"]');
    if (metaD && d['_meta_desc']) metaD.setAttribute('content', d['_meta_desc']);

    /* Lang select dropdown */
    var langSel = document.querySelector('.lang-select');
    if (langSel) {
      langSel.value = lang;
      var curPage = window.location.pathname.split('/').pop() || 'index.html';
      if (!curPage || curPage === '/') curPage = 'index.html';
      langSel.addEventListener('change', function () {
        window.location.href = curPage + '?lang=' + this.value;
      });
    }

    /* Lang switcher (legacy link-based, kept for backward compat) */
    var curPageLs = window.location.pathname.split('/').pop() || 'index.html';
    if (!curPageLs || curPageLs === '/') curPageLs = 'index.html';
    document.querySelectorAll('.lang-switcher a').forEach(function (a) {
      var m = a.href.match(/[?&]lang=([a-z]+)/);
      var aLang = m ? m[1] : null;
      if (!aLang) return;
      a.href = curPageLs + '?lang=' + aLang;
      if (aLang === lang) {
        a.style.opacity    = '1';
        a.style.fontWeight = '900';
        a.style.textDecoration = 'underline';
      } else {
        a.style.opacity    = '0.65';
        a.style.fontWeight = '700';
        a.style.textDecoration = 'none';
      }
    });
  }

  /* ── Bootstrap ──────────────────────────────────────────────────────────── */
  function init() {
    var scriptEl = document.getElementById('pt');
    var pageData = scriptEl ? JSON.parse(scriptEl.textContent) : {};
    apply(getLang(), pageData);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
