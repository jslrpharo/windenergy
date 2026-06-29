(function () {
  var labels = {
    es: { privacy: 'Politica de privacidad', cookies: 'Politica de cookies', contact: 'Contacto', aria: 'Enlaces legales' },
    en: { privacy: 'Privacy Policy', cookies: 'Cookie Policy', contact: 'Contact', aria: 'Legal links' },
    fr: { privacy: 'Politique de confidentialite', cookies: 'Politique de cookies', contact: 'Contact', aria: 'Liens juridiques' },
    de: { privacy: 'Datenschutzerklarung', cookies: 'Cookie-Richtlinie', contact: 'Kontakt', aria: 'Rechtliche Links' },
    it: { privacy: 'Informativa sulla privacy', cookies: 'Informativa sui cookie', contact: 'Contatto', aria: 'Link legali' },
    pt: { privacy: 'Politica de privacidade', cookies: 'Politica de cookies', contact: 'Contacto', aria: 'Links legais' }
  };

  function getLang() {
    var lang = (document.documentElement.lang || 'es').toLowerCase().split('-')[0];
    return labels[lang] ? lang : 'es';
  }

  function getHref(path, lang) {
    return path + '?lang=' + lang;
  }

  function ensureFooterLinks() {
    var footer = document.querySelector('footer');
    if (!footer || footer.querySelector('.legal-footer-links')) return;

    var lang = getLang();
    var copy = labels[lang];
    var nav = document.createElement('nav');
    nav.className = 'legal-footer-links';
    nav.setAttribute('aria-label', copy.aria);
    nav.style.marginTop = '0.8rem';
    nav.style.display = 'flex';
    nav.style.flexWrap = 'wrap';
    nav.style.justifyContent = 'center';
    nav.style.gap = '0.4rem 1rem';
    nav.style.fontSize = '0.85rem';
    nav.style.opacity = '0.9';

    nav.innerHTML =
      '<a href="' + getHref('/politica-privacidad.html', lang) + '" style="color:inherit;">' + copy.privacy + '</a>' +
      '<a href="' + getHref('/politica-cookies.html', lang) + '" style="color:inherit;">' + copy.cookies + '</a>' +
      '<a href="' + getHref('/contacto.html', lang) + '" style="color:inherit;">' + copy.contact + '</a>';

    footer.appendChild(nav);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', ensureFooterLinks);
  } else {
    ensureFooterLinks();
  }
})();
