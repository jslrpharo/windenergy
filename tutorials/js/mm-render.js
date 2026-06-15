// Wind Energy Knowledge Map - D3.js Renderer
// Parses Freeplane .mm XML data and renders an interactive tree
(function () {
  "use strict";

  // Configuration
  var INITIAL_DEPTH = 2;
  var TRANSITION_MS = 400;
  var NODE_RADIUS = 6;
  var NODE_RADIUS_ROOT = 10;
  var LINK_ICON = "\uD83D\uDD17";

  // Color palette by depth
  var DEPTH_COLORS = [
    "#006699",
    "#ff9900", "#9900ff", "#00007c", "#00ff00", "#ff6666",
    "#0000ff", "#ff00ff", "#00ffff", "#cc6600", "#009900", "#cc0000"
  ];

  // DOM references
  var container   = document.getElementById("mindmap-container");
  var svgWrap     = document.getElementById("svg-wrap");
  var loadingEl   = document.getElementById("loading-status");
  var tooltipEl   = document.getElementById("tooltip");
  var breadcrumb  = document.getElementById("breadcrumb");
  var toolbarInfo = document.getElementById("toolbar-info");
  var searchInput = document.getElementById("search-input");

  // .mm XML to JSON tree parser
  function parseMMXML(xmlText) {
    var parser = new DOMParser();
    var doc = parser.parseFromString(xmlText, "application/xml");
    var parseErr = doc.querySelector("parsererror");
    if (parseErr) throw new Error("XML parse error: " + parseErr.textContent.slice(0, 200));

    var mapEl = doc.querySelector("map");
    if (!mapEl) throw new Error("No <map> element found in .mm file");

    var rootNode = mapEl.querySelector(":scope > node");
    if (!rootNode) throw new Error("No root <node> found inside <map>");

    var totalNodes = 0;

    function extractText(nodeEl) {
      var textAttr = nodeEl.getAttribute("TEXT");
      if (textAttr) return textAttr.trim();

      var rc = nodeEl.querySelector(":scope > richcontent[TYPE='NODE']");
      if (rc) {
        var bodyEl = rc.querySelector("body");
        if (bodyEl) return bodyEl.textContent.trim();
        return rc.textContent.trim();
      }

      return "(unnamed)";
    }

    function parseNode(nodeEl, depth, siblingIndex) {
      totalNodes++;
      var name = extractText(nodeEl);
      var link = nodeEl.getAttribute("LINK") || null;
      var folded = nodeEl.getAttribute("FOLDED") === "true";
      var color = nodeEl.getAttribute("COLOR") || null;
      var bgColor = nodeEl.getAttribute("BACKGROUND_COLOR") || null;

      var edgeEl = nodeEl.querySelector(":scope > edge");
      var edgeColor = edgeEl ? edgeEl.getAttribute("COLOR") : null;

      var childEls = nodeEl.querySelectorAll(":scope > node");
      var children = [];
      childEls.forEach(function (ch, i) {
        children.push(parseNode(ch, depth + 1, i));
      });

      return {
        name: name,
        link: link,
        folded: folded,
        color: color,
        bgColor: bgColor,
        edgeColor: edgeColor,
        depth: depth,
        siblingIndex: siblingIndex,
        children: children.length > 0 ? children : undefined
      };
    }

    var tree = parseNode(rootNode, 0, 0);
    return { tree: tree, totalNodes: totalNodes };
  }

  // Color helpers
  function assignBranchColors(root) {
    root._branchColor = DEPTH_COLORS[0];

    if (!root.children) return;

    root.children.forEach(function (child, i) {
      var base = child.edgeColor || DEPTH_COLORS[(i % (DEPTH_COLORS.length - 1)) + 1];
      propagateColor(child, base, 1);
    });

    function propagateColor(node, baseColor, depth) {
      if (depth <= 1) {
        node._branchColor = baseColor;
      } else {
        var t = Math.min((depth - 1) * 0.12, 0.7);
        node._branchColor = blendToWhite(baseColor, t);
      }
      if (node.children) {
        node.children.forEach(function (ch) {
          propagateColor(ch, baseColor, depth + 1);
        });
      }
    }
  }

  function blendToWhite(hex, t) {
    var r = parseInt(hex.slice(1, 3), 16);
    var g = parseInt(hex.slice(3, 5), 16);
    var b = parseInt(hex.slice(5, 7), 16);
    var mix = function (c) { return Math.round(c + (255 - c) * t); };
    return "#" + [mix(r), mix(g), mix(b)].map(function (v) {
      return v.toString(16).padStart(2, "0");
    }).join("");
  }

  // Collapse helpers
  function collapseToDepth(node, maxDepth, currentDepth) {
    if (currentDepth === undefined) currentDepth = 0;
    if (node.children) {
      if (currentDepth >= maxDepth) {
        node._children = node.children;
        node.children = null;
      } else {
        node.children.forEach(function (c) { collapseToDepth(c, maxDepth, currentDepth + 1); });
      }
    }
    if (node._children) {
      if (currentDepth >= maxDepth) {
        node._children.forEach(function (c) { collapseToDepth(c, maxDepth, currentDepth + 1); });
      } else {
        node.children = node._children;
        node._children = null;
        node.children.forEach(function (c) { collapseToDepth(c, maxDepth, currentDepth + 1); });
      }
    }
  }

  function expandAll(node) {
    if (node._children) {
      node.children = node._children;
      node._children = null;
    }
    if (node.children) node.children.forEach(expandAll);
  }

  function hasHiddenChildren(d) {
    return d._children && d._children.length > 0;
  }

  function hasVisibleChildren(d) {
    return d.children && d.children.length > 0;
  }

  // Breadcrumb
  function showBreadcrumb(d) {
    var path = [];
    var cur = d;
    while (cur) {
      path.unshift(cur.data ? cur.data.name : cur.name);
      cur = cur.parent;
    }
    breadcrumb.innerHTML = path.map(function (p, i) {
      return i === path.length - 1
        ? "<span>" + escapeHtml(p) + "</span>"
        : escapeHtml(p);
    }).join(" &rsaquo; ");
  }

  function escapeHtml(text) {
    var div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }

  // MAIN: detect language from URL, fetch the corresponding .mm file and render
  var pathParts = window.location.pathname.split('/');
  var lang = pathParts[pathParts.length - 2] || 'en';
  var validLangs = ['en', 'es', 'fr', 'de', 'it', 'pt'];
  if (validLangs.indexOf(lang) === -1) lang = 'en';
  var mmUrl = '../data/wind_energy_mindmap-' + lang + '.mm';

  fetch(mmUrl)
    .then(function (response) {
      if (!response.ok) throw new Error('HTTP ' + response.status + ' al cargar ' + mmUrl);
      return response.text();
    })
    .then(function (mmXml) {
      var result = parseMMXML(mmXml);
      assignBranchColors(result.tree);
      toolbarInfo.textContent = result.totalNodes + " nodes";
      loadingEl.remove();
      renderTree(result.tree);
    })
    .catch(function (err) {
      loadingEl.classList.add('error');
      loadingEl.innerHTML = '<div class="icon">\u26A0</div><div>' + err.message + '</div>';
    });

  // D3 Tree Rendering
  function renderTree(rootData) {
    collapseToDepth(rootData, INITIAL_DEPTH);

    var width  = svgWrap.clientWidth;
    var height = svgWrap.clientHeight;
    var margin = { top: 30, right: 200, bottom: 30, left: 120 };

    var svg = d3.select(svgWrap)
      .append("svg")
      .attr("viewBox", [0, 0, width, height])
      .attr("preserveAspectRatio", "xMidYMid meet");

    var g = svg.append("g").attr("class", "mm-zoom-layer");

    var zoomBehavior = d3.zoom()
      .scaleExtent([0.15, 4])
      .on("zoom", function (event) {
        g.attr("transform", event.transform);
      });

    svg.call(zoomBehavior);

    var initialTransform = d3.zoomIdentity.translate(margin.left, height / 2).scale(0.9);
    svg.call(zoomBehavior.transform, initialTransform);

    var gLinks = g.append("g").attr("class", "mm-links-layer");
    var gNodes = g.append("g").attr("class", "mm-nodes-layer");

    var treeLayout = d3.tree().nodeSize([22, 260]);

    var rootHierarchy = d3.hierarchy(rootData);
    rootHierarchy.x0 = 0;
    rootHierarchy.y0 = 0;

    update(rootHierarchy);

    function update(source) {
      var root = d3.hierarchy(rootData);
      root.x0 = source.x0 || 0;
      root.y0 = source.y0 || 0;

      treeLayout(root);

      var nodes = root.descendants();
      var links = root.links();

      nodes.forEach(function (d) {
        d.y = d.depth * 260;
      });

      // LINKS
      var link = gLinks.selectAll("path.mm-link")
        .data(links, function (d) { return d.target.data.name + "-" + d.target.data.siblingIndex + "-" + d.target.depth; });

      var linkEnter = link.enter()
        .append("path")
        .attr("class", "mm-link")
        .attr("d", function () {
          var o = { x: source.x0, y: source.y0 };
          return diagonal(o, o);
        })
        .attr("stroke", function (d) {
          return d.target.data._branchColor || "#ccc";
        });

      var linkUpdate = linkEnter.merge(link);

      linkUpdate.transition()
        .duration(TRANSITION_MS)
        .attr("d", function (d) { return diagonal(d.source, d.target); })
        .attr("stroke", function (d) {
          return d.target.data._branchColor || "#ccc";
        });

      link.exit()
        .transition()
        .duration(TRANSITION_MS)
        .attr("d", function () {
          var o = { x: source.x || 0, y: source.y || 0 };
          return diagonal(o, o);
        })
        .remove();

      // NODES
      var node = gNodes.selectAll("g.mm-node")
        .data(nodes, function (d) { return d.data.name + "-" + d.data.siblingIndex + "-" + d.depth; });

      var nodeEnter = node.enter()
        .append("g")
        .attr("class", "mm-node")
        .attr("transform", function () {
          return "translate(" + (source.y0 || 0) + "," + (source.x0 || 0) + ")";
        })
        .on("click", function (event, d) {
          event.stopPropagation();
          if (event.target.classList.contains("link-icon")) return;
          toggle(d, root);
        })
        .on("mouseover", function (event, d) {
          showBreadcrumb(d);
          if (d.data.name.length > 50 || d.data.link) {
            showTooltip(event, d);
          }
        })
        .on("mouseout", function () {
          hideTooltip();
        });

      nodeEnter.append("circle")
        .attr("r", function (d) { return d.depth === 0 ? NODE_RADIUS_ROOT : NODE_RADIUS; })
        .attr("fill", function (d) {
          if (hasHiddenChildren(d.data)) return d.data._branchColor || "#006699";
          if (hasVisibleChildren(d.data)) return "white";
          return d.data._branchColor || "#aaa";
        })
        .attr("stroke", function (d) {
          return d.data._branchColor || "#006699";
        });

      nodeEnter.append("text")
        .attr("class", function (d) { return d.depth === 0 ? "node-label-root" : "node-label"; })
        .attr("dy", "0.35em")
        .attr("x", function (d) {
          return d.depth === 0 ? (NODE_RADIUS_ROOT + 8) : (hasVisibleChildren(d.data) || hasHiddenChildren(d.data) ? (NODE_RADIUS + 8) : (NODE_RADIUS + 6));
        })
        .text(function (d) {
          var name = d.data.name;
          return name.length > 60 ? name.slice(0, 57) + "..." : name;
        });

      nodeEnter.filter(function (d) { return !!d.data.link; })
        .append("text")
        .attr("class", "link-icon")
        .attr("x", function (d) {
          var labelLen = Math.min(d.data.name.length, 60);
          var offset = d.depth === 0 ? (NODE_RADIUS_ROOT + 8) : (NODE_RADIUS + 8);
          return offset + labelLen * 6.5 + 8;
        })
        .attr("dy", "0.35em")
        .attr("font-size", "11px")
        .text(LINK_ICON)
        .style("cursor", "pointer")
        .on("click", function (event, d) {
          event.stopPropagation();
          window.open(d.data.link, "_blank", "noopener");
        });

      nodeEnter.filter(function (d) { return hasHiddenChildren(d.data); })
        .append("text")
        .attr("class", "mm-badge-text")
        .attr("x", 0)
        .attr("dy", "0.35em")
        .attr("text-anchor", "middle")
        .attr("fill", "white")
        .attr("font-size", "8px")
        .attr("font-weight", "700")
        .attr("pointer-events", "none")
        .text(function (d) {
          var n = d.data._children ? d.data._children.length : 0;
          return n > 0 ? n : "";
        });

      var nodeUpdate = nodeEnter.merge(node);

      nodeUpdate.transition()
        .duration(TRANSITION_MS)
        .attr("transform", function (d) {
          return "translate(" + d.y + "," + d.x + ")";
        });

      nodeUpdate.select("circle")
        .attr("r", function (d) { return d.depth === 0 ? NODE_RADIUS_ROOT : NODE_RADIUS; })
        .attr("fill", function (d) {
          if (hasHiddenChildren(d.data)) return d.data._branchColor || "#006699";
          if (hasVisibleChildren(d.data)) return "white";
          return d.data._branchColor || "#aaa";
        })
        .attr("stroke", function (d) {
          return d.data._branchColor || "#006699";
        });

      nodeUpdate.select(".mm-badge-text")
        .text(function (d) {
          var n = d.data._children ? d.data._children.length : 0;
          return n > 0 ? n : "";
        });

      var nodeExit = node.exit()
        .transition()
        .duration(TRANSITION_MS)
        .attr("transform", function () {
          return "translate(" + (source.y || 0) + "," + (source.x || 0) + ")";
        })
        .remove();

      nodeExit.select("circle").attr("r", 1e-6);
      nodeExit.select("text").style("fill-opacity", 1e-6);

      nodes.forEach(function (d) {
        d.x0 = d.x;
        d.y0 = d.y;
      });
    }

    function toggle(d, root) {
      if (d.data.children) {
        d.data._children = d.data.children;
        d.data.children = null;
      } else if (d.data._children) {
        d.data.children = d.data._children;
        d.data._children = null;
      }
      var fakeSource = { x0: d.x, y0: d.y, x: d.x, y: d.y };
      update(fakeSource);
    }

    function diagonal(s, d) {
      return "M" + s.y + "," + s.x +
        "C" + ((s.y + d.y) / 2) + "," + s.x +
        " " + ((s.y + d.y) / 2) + "," + d.x +
        " " + d.y + "," + d.x;
    }

    function showTooltip(event, d) {
      var html = "<strong>" + escapeHtml(d.data.name) + "</strong>";
      if (d.data.link) {
        html += "<br><span style=\"color:#6bb8e8\">" + escapeHtml(d.data.link) + "</span>";
      }
      var hidden = d.data._children ? d.data._children.length : 0;
      if (hidden > 0) {
        html += "<br><span style=\"opacity:0.7\">" + hidden + " collapsed children</span>";
      }
      tooltipEl.innerHTML = html;
      tooltipEl.classList.add("visible");

      var rect = container.getBoundingClientRect();
      var ex = event.clientX - rect.left + 15;
      var ey = event.clientY - rect.top + 15;
      tooltipEl.style.left = ex + "px";
      tooltipEl.style.top = ey + "px";
    }

    function hideTooltip() {
      tooltipEl.classList.remove("visible");
    }

    // Toolbar actions
    document.getElementById("btn-expand").addEventListener("click", function () {
      expandAll(rootData);
      update({ x0: 0, y0: 0, x: 0, y: 0 });
    });

    document.getElementById("btn-collapse").addEventListener("click", function () {
      expandAll(rootData);
      collapseToDepth(rootData, INITIAL_DEPTH);
      update({ x0: 0, y0: 0, x: 0, y: 0 });
      svg.transition().duration(TRANSITION_MS)
        .call(zoomBehavior.transform, initialTransform);
    });

    document.getElementById("btn-reset").addEventListener("click", function () {
      svg.transition().duration(TRANSITION_MS)
        .call(zoomBehavior.transform, initialTransform);
    });

    document.getElementById("btn-zoom-in").addEventListener("click", function () {
      svg.transition().duration(300).call(zoomBehavior.scaleBy, 1.4);
    });

    document.getElementById("btn-zoom-out").addEventListener("click", function () {
      svg.transition().duration(300).call(zoomBehavior.scaleBy, 0.7);
    });

    // Search
    var btnSearch = document.getElementById("btn-search");
    var btnClear  = document.getElementById("btn-clear-search");

    function doSearch() {
      var query = searchInput.value.trim().toLowerCase();
      if (!query) { clearSearch(); return; }

      expandAll(rootData);
      update({ x0: 0, y0: 0, x: 0, y: 0 });

      setTimeout(function () {
        var allNodes = gNodes.selectAll("g.mm-node");
        var matchCount = 0;
        var firstMatch = null;

        allNodes.classed("highlight-match", function (d) {
          var match = d.data.name.toLowerCase().includes(query);
          if (match) {
            matchCount++;
            if (!firstMatch) firstMatch = d;
          }
          return match;
        });

        toolbarInfo.textContent = matchCount + " match" + (matchCount !== 1 ? "es" : "") + " found";
        btnClear.style.display = "inline-flex";

        if (firstMatch) {
          var t = d3.zoomIdentity
            .translate(width / 2 - firstMatch.y, height / 2 - firstMatch.x)
            .scale(1);
          svg.transition().duration(500).call(zoomBehavior.transform, t);
        }
      }, TRANSITION_MS + 50);
    }

    function clearSearch() {
      searchInput.value = "";
      gNodes.selectAll("g.mm-node").classed("highlight-match", false);
      btnClear.style.display = "none";

      expandAll(rootData);
      collapseToDepth(rootData, INITIAL_DEPTH);
      update({ x0: 0, y0: 0, x: 0, y: 0 });
      svg.transition().duration(TRANSITION_MS)
        .call(zoomBehavior.transform, initialTransform);

      toolbarInfo.textContent = countAllNodes(rootData) + " nodes";
    }

    function countAllNodes(node) {
      var n = 1;
      var ch = node.children || node._children;
      if (ch) ch.forEach(function (c) { n += countAllNodes(c); });
      return n;
    }

    btnSearch.addEventListener("click", doSearch);
    btnClear.addEventListener("click", clearSearch);
    searchInput.addEventListener("keydown", function (e) {
      if (e.key === "Enter") doSearch();
      if (e.key === "Escape") clearSearch();
    });

  }

})();
