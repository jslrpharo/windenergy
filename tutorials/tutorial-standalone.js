(function () {
  var fromQuery = new URLSearchParams(window.location.search).get('from') === 'launcher';
  var fromHash  = window.location.hash === '#from=launcher';
  if (!fromQuery && !fromHash) return;

  document.body.classList.add('standalone');

  var titles = {
    es: 'Simuladores y Herramientas de Aerogeneradores en Tiempo Real',
    en: 'Wind Turbine Real-Time Simulators, Training & Engineering Tools',
    fr: "Simulateurs d'éoliennes en temps réel, formation et outils d'ingénierie",
    it: 'Simulatori di turbine eoliche in tempo reale, formazione e strumenti ingegneristici',
    de: 'Echtzeit-Windturbinen-Simulatoren, Schulung und Ingenieurwerkzeuge',
    pt: 'Simuladores de turbinas eólicas em tempo real, treinamento e ferramentas de engenharia'
  };

  var lang = (document.documentElement.lang || 'en').toLowerCase().slice(0, 2);
  var titleText = titles[lang] || titles.en;

  var headerLeft = document.querySelector('.tut-header-left');
  if (headerLeft) {
    var titleEl = document.createElement('div');
    titleEl.className = 'tut-standalone-title';
    titleEl.textContent = titleText;
    headerLeft.appendChild(titleEl);
  }
})();
