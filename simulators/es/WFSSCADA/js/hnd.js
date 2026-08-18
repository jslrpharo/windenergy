jQuery.fn.highlight=function(a){function d(b,a){var e=0;if(b.nodeType==3){var c=b.data.toUpperCase().indexOf(a);if(c>=0){e=document.createElement("span");e.className="highlight";c=b.splitText(c);c.splitText(a.length);var g=c.cloneNode(!0);e.appendChild(g);c.parentNode.replaceChild(e,c);e=1}}else if(b.nodeType==1&&b.childNodes&&!/(script|style)/i.test(b.tagName))for(c=0;c<b.childNodes.length;++c)c+=d(b.childNodes[c],a);return e}return this.each(function(){d(this,a.toUpperCase())})}; jQuery.fn.removeHighlight=function(){return this.find("span.highlight").each(function(){with(this.parentNode)replaceChild(this.firstChild,this),normalize()}).end()};$.extend({getUrlVars:function(){for(var a=[],d,b=document.location.href.slice(document.location.href.indexOf("?")+1).split("&"),f=0;f<b.length;f++)d=b[f].split("="),a.push(d[0]),a[d[0]]=d[1];return a},getUrlVar:function(a){return $.getUrlVars()[a]}}); $(document).ready(function(){var a=$.getUrlVar("search");a&&a!=""&&(a=unescape(a))&&$.each(a.split(" "),function(a,b){b!="AND"&&b!="NOT"&&b!="OR"&&b!=""&&b!=" "&&$("#topic_content").highlight(b)&&$("#topic_header_text").highlight(b)&&$("#topic_footer_content").highlight(b)})});

var HND_CURRENT_TUTORIAL = "WFSSCADA";
var HND_TUTORIAL_ENTRIES = {"DSASTutorial":"DSASTutorial.html","DSASExercises":"DSASExercises.html","RRCTutorial":"RotorResistorContolledWT.html","RRCExercises":"RotorResistorContolledWT.html","DFIGTutorial":"DFIGWTSimulator.html","DFIGExercises":"DFIGWTSimulator.html","WFSSCADA":"SimuladorParqueEolico.html","Experiments":"Experiments.html"};
function openTopic(href) {
    if (!href || href == "#") return;
    if (href.indexOf("../") !== 0) { window.open(href, "FrameMain"); return; }
    var sRest = href.substring(3);
    var nSlash = sRest.indexOf("/");
    if (nSlash < 0) { window.open(href, "FrameMain"); return; }
    var sTutorial = sRest.substring(0, nSlash);
    var sFile = sRest.substring(nSlash + 1);
    if (sTutorial === HND_CURRENT_TUTORIAL) { window.open(href, "FrameMain"); return; }
    var sEntry = HND_TUTORIAL_ENTRIES[sTutorial];
    var nQ = sFile.indexOf("?");
    var sPath = (nQ >= 0) ? sFile.substring(0, nQ) : sFile;
    var sQuery = (nQ >= 0) ? sFile.substring(nQ) : "";
    if (sQuery.indexOf("?search=") === 0) sQuery = "";
    if (!sEntry) {
        window.open("../" + sTutorial + "/" + sPath + sQuery, "_blank");
    } else if (sPath === sEntry) {
        window.open("../" + sTutorial + "/" + sPath + sQuery, "_blank");
    } else {
        window.open("../" + sTutorial + "/" + sEntry + "?" + sPath + sQuery, "_blank");
    }
}

$(document).ready(function() {
    $(document).on("click", "a[href]", function(e) {
        var href = this.getAttribute("href") || "";
        if (href.indexOf("../") !== 0) return;
        var sRest = href.substring(3);
        var nSlash = sRest.indexOf("/");
        if (nSlash < 0) return;
        var sTutorial = sRest.substring(0, nSlash);
        if (sTutorial === HND_CURRENT_TUTORIAL) return;
        e.preventDefault();
        openTopic(href);
    });
});
