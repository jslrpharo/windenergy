(function () {
  if (new URLSearchParams(window.location.search).get('from') === 'launcher') {
    document.body.classList.add('standalone');
  }
})();
