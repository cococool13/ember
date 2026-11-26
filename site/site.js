/* Page furniture that must work without the hero: FAQ disclosures close on Escape,
   and the download link never turns an unavailable file into a purchase prompt. */
(function () {
  'use strict';

  document.addEventListener('keydown', function (event) {
    if (event.key !== 'Escape') return;
    var open =
      document.activeElement && document.activeElement.closest
        ? document.activeElement.closest('details[open]')
        : null;
    if (open) {
      open.open = false;
      var summary = open.querySelector('summary');
      if (summary) summary.focus();
    }
  });

  // Never turn an unavailable download into a purchase prompt.
  var links = Array.from(document.querySelectorAll('.download-link'));
  var note = document.getElementById('download-note');
  if (!links.length) return;
  var installHelp = document.getElementById('download-help');
  links.forEach(function (link) {
    link.addEventListener('click', function (event) {
      if (link.getAttribute('aria-disabled') === 'true') {
        event.preventDefault();
        return;
      }
      if (!installHelp) return;
      installHelp.hidden = false;
      installHelp.focus({ preventScroll: true });
      installHelp.scrollIntoView({
        behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches
          ? 'instant'
          : 'smooth',
        block: 'start',
      });
    });
  });
  function unavailable() {
    links.forEach(function (link) {
      link.removeAttribute('href');
      link.setAttribute('aria-disabled', 'true');
      link.textContent = 'Download unavailable';
    });
    if (note)
      note.textContent =
        'The download is temporarily unavailable. Please check back or contact support before purchasing.';
  }
  fetch(links[0].getAttribute('href'), { method: 'HEAD' })
    .then(function (response) {
      var type = response.headers.get('content-type') || '';
      if (!response.ok || type.indexOf('text/html') !== -1) unavailable();
    })
    .catch(unavailable);
})();
