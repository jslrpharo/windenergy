/* ================================================================
   LdP_Help — Theme toggle + persistence
   Applies [data-theme="dark"] on <html> for CSS custom-property swap.
   Theme is saved to localStorage and synced across frameset frames.
   ================================================================ */
(function () {
    'use strict';

    var STORAGE_KEY = 'ldp-theme';

    function getTheme() {
        try { return localStorage.getItem(STORAGE_KEY) || 'light'; }
        catch (e) { return 'light'; }
    }

    function setTheme(theme) {
        try { localStorage.setItem(STORAGE_KEY, theme); } catch (e) {}
        document.documentElement.setAttribute('data-theme', theme);
        updateButton();
        syncFrames(theme);
    }

    function updateButton() {
        var btn = document.getElementById('ldp-theme-toggle');
        if (!btn) return;
        var dark = document.documentElement.getAttribute('data-theme') === 'dark';
        btn.innerHTML = dark
            ? '<span class="ldp-icon">\u2600\uFE0F</span> Light mode'
            : '<span class="ldp-icon">\uD83C\uDF19</span> Dark mode';
    }

    function syncFrames(theme) {
        try {
            if (top && top !== window) {
                // Apply to the frameset document itself
                try { top.document.documentElement.setAttribute('data-theme', theme); } catch (e) {}
                // Apply to each sibling frame
                for (var i = 0; i < top.frames.length; i++) {
                    try { top.frames[i].document.documentElement.setAttribute('data-theme', theme); } catch (e) {}
                }
            }
        } catch (e) {}
    }

    // Apply theme ASAP (avoids flash of wrong colours)
    document.documentElement.setAttribute('data-theme', getTheme());

    document.addEventListener('DOMContentLoaded', function () {
        // Re-confirm theme after DOM is ready
        document.documentElement.setAttribute('data-theme', getTheme());

        var btn = document.getElementById('ldp-theme-toggle');
        if (btn) {
            btn.addEventListener('click', function () {
                var next = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
                setTheme(next);
            });
            updateButton();
        }
    });

    // Expose for external calls (e.g. from other frames)
    window.LdpTheme = {
        set: setTheme,
        get: getTheme
    };
})();
