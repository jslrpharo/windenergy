(function () {
  const mainScrollRoot = document.querySelector(".help-main");

  // Hash actual rastreado internamente para no provocar scroll del navegador
  var _navHash = window.location.hash || "";

  function getScrollElement() {
    return mainScrollRoot || document.scrollingElement || document.documentElement;
  }

  function normalizeText(text) {
    return (text || "")
      .toLowerCase()
      .normalize("NFD")
      .replace(/[̀-ͯ]/g, "")
      .replace(/\s+/g, " ")
      .trim();
  }

  function escapeHtml(text) {
    return (text || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function highlightSnippet(text, terms) {
    let result = escapeHtml(text);
    terms.forEach(function (term) {
      if (!term) {
        return;
      }
      const escaped = term.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      const pattern = new RegExp("(" + escaped + ")", "ig");
      result = result.replace(pattern, "<mark>$1</mark>");
    });
    return result;
  }

  function createSnippet(text, rawQuery) {
    const normalizedText = normalizeText(text);
    const normalizedQuery = normalizeText(rawQuery);
    const terms = normalizedQuery.split(/\s+/).filter(Boolean);

    if (!normalizedText || terms.length === 0) {
      return escapeHtml((text || "").slice(0, 220));
    }

    let firstIndex = -1;
    terms.forEach(function (term) {
      const idx = normalizedText.indexOf(term);
      if (idx >= 0 && (firstIndex < 0 || idx < firstIndex)) {
        firstIndex = idx;
      }
    });

    if (firstIndex < 0) {
      return escapeHtml((text || "").slice(0, 220));
    }

    const start = Math.max(0, firstIndex - 80);
    const end = Math.min(text.length, firstIndex + 160);
    const prefix = start > 0 ? "..." : "";
    const suffix = end < text.length ? "..." : "";
    return prefix + highlightSnippet(text.slice(start, end), terms) + suffix;
  }

  function activateTab(tabName) {
    document.querySelectorAll(".help-tab").forEach(function (button) {
      button.classList.toggle("is-active", button.dataset.tab === tabName);
    });
    document.querySelectorAll(".help-panel").forEach(function (panel) {
      panel.classList.toggle("is-active", panel.dataset.panel === tabName);
    });
  }

  function highlightTarget(targetId) {
    if (!targetId) {
      return;
    }
    const target = document.getElementById(targetId);
    if (!target) {
      return;
    }

    // Si el target es una <section>, scrollar al primer heading interior para
    // que el texto del título quede justo bajo la toolbar.
    const heading = (target.tagName === "SECTION")
      ? target.querySelector("h1, h2, h3, h4")
      : null;
    const anchor = heading || target;

    // scrollIntoView usa scroll-padding-top del contenedor (establecido en init)
    // para despejar la toolbar sticky sin cálculo manual.
    anchor.scrollIntoView({ behavior: "smooth", block: "start" });

    target.classList.remove("content-highlight");
    void target.offsetWidth;
    target.classList.add("content-highlight");
  }

  function currentState() {
    const scrollElement = getScrollElement();
    return {
      hash: _navHash,
      scrollY: scrollElement ? scrollElement.scrollTop || 0 : 0
    };
  }

  function sameState(a, b) {
    if (!a || !b) {
      return false;
    }
    return a.hash === b.hash && Math.abs((a.scrollY || 0) - (b.scrollY || 0)) < 4;
  }

  function restoreState(state) {
    if (!state) {
      return;
    }

    const scrollElement = getScrollElement();

    _navHash = state.hash || "";

    if (state.hash) {
      try {
        history.replaceState(null, "", state.hash);
      } catch (e) {
        /* fallback silencioso */
      }
    } else {
      try {
        history.replaceState(null, "", window.location.pathname + window.location.search);
      } catch (e) {
        /* fallback silencioso */
      }
    }

    if (scrollElement) {
      scrollElement.scrollTo({ top: state.scrollY || 0, behavior: "auto" });
    }

    if (state.hash) {
      const targetId = state.hash.replace(/^#/, "");
      const target = document.getElementById(targetId);
      if (target) {
        target.classList.remove("content-highlight");
        void target.offsetWidth;
        target.classList.add("content-highlight");
      }
    }
  }

  const backStack = [];
  const forwardStack = [];

  function updateNavButtons() {
    const backButton = document.getElementById("help-back-button");
    const forwardButton = document.getElementById("help-forward-button");
    if (backButton) {
      backButton.disabled = backStack.length === 0;
    }
    if (forwardButton) {
      forwardButton.disabled = forwardStack.length === 0;
    }
  }

  function pushCurrentToBackStack() {
    const state = currentState();
    const last = backStack.length > 0 ? backStack[backStack.length - 1] : null;
    if (!sameState(state, last)) {
      backStack.push(state);
    }
    forwardStack.length = 0;
    updateNavButtons();
  }

  function buildSections() {
    const root = document.querySelector(".content-body");
    const sectionNodes = root ? Array.from(root.querySelectorAll("section[id]")) : [];

    return sectionNodes.map(function (sectionNode) {
      const directChildren = Array.from(sectionNode.children);
      const heading = directChildren.find(function (child) {
        return /^H[1-3]$/.test(child.tagName || "");
      });
      const textParts = [];

      directChildren.forEach(function (child) {
        if (child.tagName === "SECTION") {
          return;
        }
        textParts.push((child.textContent || "").trim());
      });

      const title = heading ? heading.textContent.trim() : sectionNode.id;
      const level = heading ? Number(heading.tagName.substring(1)) : 3;
      const text = textParts.join(" ").replace(/\s+/g, " ").trim();
      const normalized = normalizeText(text);
      return {
        id: sectionNode.id,
        title: title,
        level: level,
        text: text,
        normalizedText: normalized,
        normalizedTitle: normalizeText(title)
      };
    });
  }

  function scoreSection(section, terms) {
    let score = 0;
    terms.forEach(function (term) {
      if (!term) {
        return;
      }

      if (section.normalizedTitle.indexOf(term) >= 0) {
        score += 12;
      }

      let fromIndex = 0;
      let count = 0;
      while (true) {
        const idx = section.normalizedText.indexOf(term, fromIndex);
        if (idx < 0) {
          break;
        }
        count += 1;
        fromIndex = idx + term.length;
      }

      score += Math.min(count, 8) * 3;
    });

    if (terms.length > 1 && terms.every(function (term) { return section.normalizedText.indexOf(term) >= 0; })) {
      score += 10;
    }

    return score;
  }

  function renderSearchResults(sections) {
    const input = document.getElementById("help-search-input");
    const results = document.getElementById("search-results");
    const empty = document.getElementById("search-empty");

    function refresh() {
      const rawQuery = input.value || "";
      const normalizedQuery = normalizeText(rawQuery);
      const terms = normalizedQuery.split(/\s+/).filter(Boolean);

      results.innerHTML = "";

      if (terms.length === 0) {
        empty.textContent = "Digita una o più parole per cercare per titoli e contenuto.";
        return;
      }

      const matches = sections
        .map(function (section) {
          return {
            section: section,
            score: scoreSection(section, terms)
          };
        })
        .filter(function (entry) { return entry.score > 0; })
        .sort(function (a, b) { return b.score - a.score; })
        .slice(0, 20);

      if (matches.length === 0) {
        empty.textContent = "No se han encontrado coincidencias para \"" + rawQuery + "\".";
        return;
      }

      empty.textContent = "Se han encontrado " + matches.length + " resultados relevantes.";

      matches.forEach(function (entry) {
        const section = entry.section;
        const article = document.createElement("article");
        article.className = "search-result";
        article.innerHTML =
          "<h4 class=\"search-result-title\"><a href=\"#" + section.id + "\" data-target=\"" + section.id + "\">" +
          escapeHtml(section.title) +
          "</a></h4>" +
          "<p class=\"search-result-meta\">Seccion de nivel " + section.level + " · puntuacion " + entry.score + "</p>" +
          "<p class=\"search-result-snippet\">" + createSnippet(section.text, rawQuery) + "</p>";
        results.appendChild(article);
      });
    }

    input.addEventListener("input", refresh);
    refresh();
  }

  function renderKeywords(keywordData) {
    const input = document.getElementById("help-keyword-input");
    const results = document.getElementById("keyword-results");
    const empty = document.getElementById("keyword-empty");

    function refresh() {
      const query = normalizeText(input.value || "");

      const matches = keywordData.filter(function (item) {
        if (!query) {
          return true;
        }
        const haystack = normalizeText(
          [item.keyword, item.description || "", (item.aliases || []).join(" ")].join(" ")
        );
        return haystack.indexOf(query) >= 0;
      });

      results.innerHTML = "";

      if (matches.length === 0) {
        empty.textContent = "No hay palabras clave que coincidan con el filtro actual.";
        return;
      }

      empty.textContent = matches.length + " palabras clave disponibles.";

      matches.forEach(function (item) {
        const article = document.createElement("article");
        article.className = "keyword-item";
        article.innerHTML =
          "<h4 class=\"keyword-item-title\"><a href=\"" + item.target + "\" data-target=\"" + item.target.replace(/^#/, "") + "\">" +
          escapeHtml(item.keyword) +
          "</a></h4>" +
          "<p class=\"keyword-item-meta\">" + escapeHtml((item.aliases || []).join(", ")) + "</p>" +
          "<p class=\"keyword-item-snippet\">" + escapeHtml(item.description || "") + "</p>";
        results.appendChild(article);
      });
    }

    input.addEventListener("input", refresh);
    refresh();
  }

  function wireNavigation() {
    document.addEventListener("click", function (event) {
      const anchor = event.target.closest("a[data-target], .toc-tree a[href^='#']");
      if (!anchor) {
        return;
      }

      const targetId = anchor.getAttribute("data-target") || (anchor.getAttribute("href") || "").replace(/^#/, "");
      if (!targetId) {
        return;
      }

      event.preventDefault();
      pushCurrentToBackStack();
      // Actualizar hash interno sin tocar window.location para evitar
      // el scroll asíncrono del navegador que sobreescribía nuestro scroll.
      _navHash = "#" + targetId;
      highlightTarget(targetId);
    });
  }

  function wireToolbarNavigation() {
    const homeButton = document.getElementById("help-home-button");
    const backButton = document.getElementById("help-back-button");
    const forwardButton = document.getElementById("help-forward-button");

    if (homeButton) {
      homeButton.addEventListener("click", function () {
        const scrollElement = getScrollElement();
        pushCurrentToBackStack();
        _navHash = "";
        history.replaceState(null, "", window.location.pathname + window.location.search);
        if (scrollElement) {
          scrollElement.scrollTo({ top: 0, behavior: "smooth" });
        }
      });
    }

    if (backButton) {
      backButton.addEventListener("click", function () {
        if (backStack.length === 0) {
          return;
        }
        const previous = backStack.pop();
        const state = currentState();
        const lastForward = forwardStack.length > 0 ? forwardStack[forwardStack.length - 1] : null;
        if (!sameState(state, lastForward)) {
          forwardStack.push(state);
        }
        restoreState(previous);
        updateNavButtons();
      });
    }

    if (forwardButton) {
      forwardButton.addEventListener("click", function () {
        if (forwardStack.length === 0) {
          return;
        }
        const next = forwardStack.pop();
        const state = currentState();
        const lastBack = backStack.length > 0 ? backStack[backStack.length - 1] : null;
        if (!sameState(state, lastBack)) {
          backStack.push(state);
        }
        restoreState(next);
        updateNavButtons();
      });
    }

    updateNavButtons();
  }

  document.querySelectorAll(".help-tab").forEach(function (button) {
    button.addEventListener("click", function () {
      activateTab(button.dataset.tab);
    });
  });

  activateTab("content");
  wireNavigation();
  wireToolbarNavigation();

  const sections = buildSections();
  renderSearchResults(sections);

  let keywordData = [];
  const keywordNode = document.getElementById("help-keywords-data");
  if (keywordNode) {
    try {
      keywordData = JSON.parse(keywordNode.textContent || "[]");
    } catch (error) {
      keywordData = [];
    }
  }
  renderKeywords(keywordData);

  // Decirle al browser cuánto espacio dejar al hacer scrollIntoView,
  // equivalente a la altura de la toolbar sticky + 8 px de respiro.
  var _tb = document.querySelector(".help-main-toolbar");
  var _sc = getScrollElement();
  if (_tb && _sc) {
    _sc.style.scrollPaddingTop = (_tb.offsetHeight + 8) + "px";
  }

  if (window.location.hash) {
    const targetId = window.location.hash.replace(/^#/, "");
    _navHash = window.location.hash;
    setTimeout(function () {
      highlightTarget(targetId);
    }, 120);
  }
})();
