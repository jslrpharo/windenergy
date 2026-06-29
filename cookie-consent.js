(function () {
  var storageKey = 'acmsl_cookie_consent';
  var acceptedValue = 'accepted';
  var rejectedValue = 'rejected';
  var messages = {
    en: {
      label: 'Cookie consent',
      title: 'Analytics cookies',
      text: 'We use Google Analytics to understand how this website is used and improve its content. You can accept or reject analytics cookies.',
      accept: 'Accept analytics',
      reject: 'Reject'
    },
    es: {
      label: 'Consentimiento de cookies',
      title: 'Cookies analiticas',
      text: 'Utilizamos Google Analytics para entender como se usa este sitio web y mejorar su contenido. Puede aceptar o rechazar las cookies analiticas.',
      accept: 'Aceptar analitica',
      reject: 'Rechazar'
    },
    fr: {
      label: 'Consentement aux cookies',
      title: 'Cookies analytiques',
      text: 'Nous utilisons Google Analytics pour comprendre comment ce site est utilise et ameliorer son contenu. Vous pouvez accepter ou refuser les cookies analytiques.',
      accept: 'Accepter',
      reject: 'Refuser'
    },
    de: {
      label: 'Cookie-Einwilligung',
      title: 'Analyse-Cookies',
      text: 'Wir verwenden Google Analytics, um die Nutzung dieser Website zu verstehen und ihre Inhalte zu verbessern. Sie konnen Analyse-Cookies akzeptieren oder ablehnen.',
      accept: 'Analytik akzeptieren',
      reject: 'Ablehnen'
    },
    it: {
      label: 'Consenso ai cookie',
      title: 'Cookie analitici',
      text: 'Utilizziamo Google Analytics per capire come viene usato questo sito web e migliorarne i contenuti. Puoi accettare o rifiutare i cookie analitici.',
      accept: 'Accetta analitica',
      reject: 'Rifiuta'
    },
    pt: {
      label: 'Consentimento de cookies',
      title: 'Cookies analiticos',
      text: 'Utilizamos o Google Analytics para compreender como este site e utilizado e melhorar o seu conteudo. Pode aceitar ou rejeitar os cookies analiticos.',
      accept: 'Aceitar analitica',
      reject: 'Rejeitar'
    }
  };

  function getLocaleMessages() {
    var lang = (document.documentElement.lang || 'en').toLowerCase();
    if (messages[lang]) return messages[lang];
    var shortLang = lang.split('-')[0];
    return messages[shortLang] || messages.en;
  }

  function updateConsent(granted) {
    if (typeof window.gtag !== 'function') return;
    var state = granted ? 'granted' : 'denied';
    window.gtag('consent', 'update', {
      analytics_storage: state,
      ad_storage: 'denied',
      ad_user_data: 'denied',
      ad_personalization: 'denied'
    });
  }

  function getMeasurementId() {
    return window.ACMSL_GA_ID || 'G-T1XF1Z8ML9';
  }

  function disableAnalytics() {
    var measurementId = getMeasurementId();
    window['ga-disable-' + measurementId] = true;
  }

  function enableAnalytics() {
    var measurementId = getMeasurementId();
    if (!measurementId || typeof window.gtag !== 'function') return;

    window['ga-disable-' + measurementId] = false;

    if (window.ACMSL_GA_INITIALIZED) return;

    window.gtag('config', measurementId, {
      anonymize_ip: true,
      send_page_view: false
    });
    window.ACMSL_GA_INITIALIZED = true;
  }

  function clearAnalyticsCookies() {
    var cookieNames = ['_ga', '_gid', '_gat', '_ga_' + getMeasurementId().replace(/^G-/, '')];
    var hostname = window.location.hostname;
    var domainParts = hostname ? hostname.split('.') : [];
    var domains = [''];

    if (domainParts.length >= 2) {
      domains.push('.' + domainParts.slice(-2).join('.'));
    }
    if (domainParts.length >= 3) {
      domains.push('.' + domainParts.slice(-3).join('.'));
    }

    cookieNames.forEach(function (name) {
      domains.forEach(function (domain) {
        var domainPart = domain ? '; domain=' + domain : '';
        document.cookie = name + '=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/' + domainPart;
      });
    });
  }

  function trackPageView() {
    if (typeof window.gtag !== 'function') return;
    window.gtag('event', 'page_view', {
      page_title: document.title,
      page_location: window.location.href,
      page_path: window.location.pathname + window.location.search
    });
  }

  function hideBanner(banner) {
    banner.classList.remove('is-visible');
    banner.setAttribute('hidden', '');
  }

  function showBanner(banner) {
    banner.classList.add('is-visible');
    banner.removeAttribute('hidden');
  }

  function buildBanner() {
    var copy = getLocaleMessages();
    var banner = document.createElement('section');
    banner.className = 'cookie-consent';
    banner.setAttribute('hidden', '');
    banner.setAttribute('aria-label', copy.label);
    banner.innerHTML =
      '<div class="cookie-consent__inner">' +
        '<div class="cookie-consent__copy">' +
          '<p class="cookie-consent__title">' + copy.title + '</p>' +
          '<p class="cookie-consent__text">' + copy.text + '</p>' +
        '</div>' +
        '<div class="cookie-consent__actions">' +
          '<button type="button" class="cookie-consent__btn cookie-consent__btn--reject" data-consent-action="reject">' + copy.reject + '</button>' +
          '<button type="button" class="cookie-consent__btn cookie-consent__btn--accept" data-consent-action="accept">' + copy.accept + '</button>' +
        '</div>' +
      '</div>';
    return banner;
  }

  function persistChoice(value) {
    try {
      window.localStorage.setItem(storageKey, value);
    } catch (err) {}
  }

  function readChoice() {
    try {
      return window.localStorage.getItem(storageKey);
    } catch (err) {
      return null;
    }
  }

  function initBanner() {
    var currentChoice = readChoice();
    if (currentChoice === acceptedValue) {
      enableAnalytics();
      updateConsent(true);
      trackPageView();
      return;
    }
    if (currentChoice === rejectedValue) {
      disableAnalytics();
      updateConsent(false);
      clearAnalyticsCookies();
      return;
    }

    disableAnalytics();

    var banner = buildBanner();
    document.body.appendChild(banner);
    showBanner(banner);

    banner.addEventListener('click', function (event) {
      var action = event.target && event.target.getAttribute('data-consent-action');
      if (!action) return;

      if (action === 'accept') {
        persistChoice(acceptedValue);
        enableAnalytics();
        updateConsent(true);
        trackPageView();
      } else {
        persistChoice(rejectedValue);
        disableAnalytics();
        updateConsent(false);
        clearAnalyticsCookies();
      }

      hideBanner(banner);
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initBanner);
  } else {
    initBanner();
  }
})();
