(function(){
  var expandAll = document.getElementById('expand-all');
  var collapseAll = document.getElementById('collapse-all');
  function allDetails(){ return document.querySelectorAll('main details'); }
  if(expandAll) expandAll.addEventListener('click', function(){ allDetails().forEach(function(d){ d.open = true; }); });
  if(collapseAll) collapseAll.addEventListener('click', function(){ allDetails().forEach(function(d){ d.open = false; }); });

  function openAncestors(target){
    var details = target.closest('details');
    while(details){ details.open = true; details = details.parentElement && details.parentElement.closest('details'); }
    if(target.tagName === 'DETAILS') target.open = true;
  }

  document.querySelectorAll('.nav a[href^="#"]').forEach(function(a){
    a.addEventListener('click', function(e){
      var id = a.getAttribute('href').slice(1);
      var target = document.getElementById(id);
      if(!target) return;
      openAncestors(target);
    });
  });

  if(location.hash){
    var hashTarget = document.getElementById(location.hash.slice(1));
    if(hashTarget){
      openAncestors(hashTarget);
      hashTarget.scrollIntoView({block:'start'});
    }
  }

  if('IntersectionObserver' in window){
    var observed = document.querySelectorAll('details.day, details.sub');
    var io = new IntersectionObserver(function(entries){
      entries.forEach(function(entry){
        var id = entry.target.id;
        var link = document.querySelector('.nav a[href="#'+id+'"]');
        if(!link) return;
        if(entry.isIntersecting) link.classList.add('active');
        else link.classList.remove('active');
      });
    }, {rootMargin:'-10% 0px -70% 0px'});
    observed.forEach(function(el){ io.observe(el); });
  }

  function fallbackCopy(text, cb){
    var ta = document.createElement('textarea');
    ta.value = text;
    ta.style.position = 'fixed';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.select();
    try{ document.execCommand('copy'); }catch(e){}
    document.body.removeChild(ta);
    if(cb) cb();
  }

  document.querySelectorAll('pre').forEach(function(pre){
    var code = pre.textContent;
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'copy-btn';
    btn.textContent = 'Copy';
    btn.setAttribute('aria-label', 'Copy code to clipboard');
    btn.addEventListener('click', function(){
      function done(){
        btn.textContent = 'Copied!';
        btn.classList.add('copied');
        setTimeout(function(){ btn.textContent = 'Copy'; btn.classList.remove('copied'); }, 1800);
      }
      if(navigator.clipboard && navigator.clipboard.writeText){
        navigator.clipboard.writeText(code).then(done, function(){ fallbackCopy(code, done); });
      } else {
        fallbackCopy(code, done);
      }
    });
    pre.appendChild(btn);
  });

  // -- Site-wide search across all week pages --
  var searchInput = document.getElementById('site-search-input');
  var resultsBox = document.getElementById('site-search-results');
  if(searchInput && resultsBox){
    var PAGES = ['index.html', 'week2.html', 'week3.html', 'week4.html', 'week5.html'];
    var searchIndex = null;
    var indexPromise = null;
    var activeIndex = -1;
    var debounceTimer = null;

    function currentPage(){
      var p = location.pathname.split('/').pop();
      return p === '' ? 'index.html' : p;
    }

    function extractSections(doc, page, pageLabel){
      var out = [];
      doc.querySelectorAll('details.sub[id]').forEach(function(sub){
        var h3 = sub.querySelector('summary h3');
        var content = sub.querySelector('.sub-content');
        if(!h3 || !content) return;
        out.push({
          page: page, pageLabel: pageLabel, id: sub.id,
          title: h3.textContent.trim(),
          body: content.textContent.replace(/\s+/g, ' ').trim()
        });
      });
      doc.querySelectorAll('details.day[id]').forEach(function(day){
        var h2 = day.querySelector('summary h2');
        var body = day.querySelector('.day-body');
        if(!h2 || !body) return;
        var clone = body.cloneNode(true);
        clone.querySelectorAll('details.sub').forEach(function(s){ s.remove(); });
        out.push({
          page: page, pageLabel: pageLabel, id: day.id,
          title: h2.textContent.trim(),
          body: clone.textContent.replace(/\s+/g, ' ').trim()
        });
      });
      return out;
    }

    function buildIndex(){
      if(indexPromise) return indexPromise;
      if(window.SEARCH_INDEX){
        searchIndex = window.SEARCH_INDEX;
        indexPromise = Promise.resolve(searchIndex);
        return indexPromise;
      }
      // Fallback if search-index.js didn't load: fetch and parse the other pages directly.
      // Only works over http(s) -- browsers block fetch() of local files under file://.
      indexPromise = Promise.all(PAGES.map(function(page){
        if(page === currentPage()){
          var label = (document.querySelector('h1') || {}).textContent || page;
          return extractSections(document, page, label.trim());
        }
        return fetch(page).then(function(r){ return r.text(); }).then(function(html){
          var doc = new DOMParser().parseFromString(html, 'text/html');
          var label = (doc.querySelector('h1') || {}).textContent || page;
          return extractSections(doc, page, label.trim());
        }).catch(function(){ return []; });
      })).then(function(arrays){
        searchIndex = [].concat.apply([], arrays);
        return searchIndex;
      });
      return indexPromise;
    }

    function escapeRe(s){ return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }
    function escapeHtml(s){ return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }

    function scoreEntry(entry, qLower){
      var titleLower = entry.title.toLowerCase();
      var bodyLower = entry.body.toLowerCase();
      var wordRe = new RegExp('\\b' + escapeRe(qLower) + '\\b');
      if(titleLower === qLower) return {rank: 0, exact: true, field: 'title'};
      if(wordRe.test(titleLower)) return {rank: 1, exact: true, field: 'title'};
      if(titleLower.indexOf(qLower) !== -1) return {rank: 2, exact: false, field: 'title'};
      if(wordRe.test(bodyLower)) return {rank: 3, exact: true, field: 'body'};
      if(bodyLower.indexOf(qLower) !== -1) return {rank: 4, exact: false, field: 'body'};
      return null;
    }

    function highlight(text, qLower){
      var idx = text.toLowerCase().indexOf(qLower);
      if(idx === -1) return escapeHtml(text);
      return escapeHtml(text.slice(0, idx)) + '<mark>' + escapeHtml(text.slice(idx, idx + qLower.length)) + '</mark>' + escapeHtml(text.slice(idx + qLower.length));
    }

    function snippet(body, qLower){
      var idx = body.toLowerCase().indexOf(qLower);
      if(idx === -1) return escapeHtml(body.slice(0, 100));
      var start = Math.max(0, idx - 40);
      var end = Math.min(body.length, idx + qLower.length + 60);
      return (start > 0 ? '…' : '') + highlight(body.slice(start, end), qLower) + (end < body.length ? '…' : '');
    }

    function render(results, q){
      if(!q){ resultsBox.hidden = true; resultsBox.innerHTML = ''; return; }
      if(results.length === 0){
        resultsBox.innerHTML = '<div class="sr-empty">No matches for "' + escapeHtml(q) + '".</div>';
        resultsBox.hidden = false;
        return;
      }
      var MAX = 30;
      var shown = results.slice(0, MAX);
      var html = shown.map(function(r){
        var titleHtml = r.field === 'title' ? highlight(r.entry.title, r.qLower) : escapeHtml(r.entry.title);
        return '<div class="sr-item" data-page="' + r.entry.page + '" data-id="' + r.entry.id + '">'
          + '<span class="sr-page">' + escapeHtml(r.entry.pageLabel) + (r.exact ? '<span class="sr-exact">exact</span>' : '') + '</span>'
          + '<span class="sr-title">' + titleHtml + '</span>'
          + '<span class="sr-snippet">' + snippet(r.entry.body, r.qLower) + '</span>'
          + '</div>';
      }).join('');
      if(results.length > MAX) html += '<div class="sr-more">' + (results.length - MAX) + ' more results — refine your search</div>';
      resultsBox.innerHTML = html;
      resultsBox.hidden = false;
    }

    function updateActive(){
      var items = resultsBox.querySelectorAll('.sr-item');
      items.forEach(function(it, i){ it.classList.toggle('active', i === activeIndex); });
      if(items[activeIndex]) items[activeIndex].scrollIntoView({block: 'nearest'});
    }

    function runSearch(q){
      buildIndex().then(function(idx){
        var qLower = q.toLowerCase();
        var results = [];
        idx.forEach(function(entry){
          var s = scoreEntry(entry, qLower);
          if(s) results.push({entry: entry, rank: s.rank, exact: s.exact, field: s.field, qLower: qLower});
        });
        results.sort(function(a, b){ return a.rank - b.rank; });
        activeIndex = -1;
        if(searchInput.value.trim() === q) render(results, q);
      });
    }

    var activeFlashMarks = [];
    function clearFlash(){
      activeFlashMarks.forEach(function(mark){
        var parent = mark.parentNode;
        if(!parent) return;
        parent.replaceChild(document.createTextNode(mark.textContent), mark);
        parent.normalize();
      });
      activeFlashMarks = [];
    }

    function flashHighlight(target, query){
      clearFlash();
      var qLower = query.toLowerCase();
      var walker = document.createTreeWalker(target, NodeFilter.SHOW_TEXT, null);
      var matches = [];
      var node;
      while((node = walker.nextNode())){
        var p = node.parentElement;
        if(p && (p.closest('pre') || p.closest('code'))) continue;
        if(node.nodeValue.toLowerCase().indexOf(qLower) !== -1){
          matches.push(node);
          if(matches.length >= 8) break;
        }
      }
      matches.forEach(function(node){
        var text = node.nodeValue;
        var idx = text.toLowerCase().indexOf(qLower);
        if(idx === -1) return;
        var before = document.createTextNode(text.slice(0, idx));
        var mark = document.createElement('mark');
        mark.className = 'hit-flash';
        mark.textContent = text.slice(idx, idx + qLower.length);
        var after = document.createTextNode(text.slice(idx + qLower.length));
        var parent = node.parentNode;
        if(!parent) return;
        parent.replaceChild(after, node);
        parent.insertBefore(mark, after);
        parent.insertBefore(before, mark);
        activeFlashMarks.push(mark);
      });
      if(activeFlashMarks.length) setTimeout(clearFlash, 4000);
    }

    function goToResult(page, id, query){
      if(page === currentPage()){
        resultsBox.hidden = true;
        var target = document.getElementById(id);
        if(!target) return;
        openAncestors(target);
        target.scrollIntoView({behavior: 'smooth', block: 'start'});
        flashHighlight(target, query);
      } else {
        try{ sessionStorage.setItem('pendingHighlight', JSON.stringify({id: id, q: query})); }catch(e){}
        location.href = page + '#' + id;
      }
    }

    searchInput.addEventListener('input', function(){
      var q = searchInput.value.trim();
      clearTimeout(debounceTimer);
      if(!q){ render([], ''); activeIndex = -1; return; }
      if(!searchIndex){
        resultsBox.innerHTML = '<div class="sr-loading">Loading search index…</div>';
        resultsBox.hidden = false;
      }
      debounceTimer = setTimeout(function(){ runSearch(q); }, 120);
    });

    searchInput.addEventListener('keydown', function(e){
      if(resultsBox.hidden) return;
      var items = resultsBox.querySelectorAll('.sr-item');
      if(e.key === 'ArrowDown'){ e.preventDefault(); activeIndex = Math.min(items.length - 1, activeIndex + 1); updateActive(); }
      else if(e.key === 'ArrowUp'){ e.preventDefault(); activeIndex = Math.max(0, activeIndex - 1); updateActive(); }
      else if(e.key === 'Enter'){
        e.preventDefault();
        var pick = items[activeIndex] || items[0];
        if(pick) goToResult(pick.getAttribute('data-page'), pick.getAttribute('data-id'), searchInput.value.trim());
      } else if(e.key === 'Escape'){
        resultsBox.hidden = true;
        resultsBox.innerHTML = '';
        activeIndex = -1;
      }
    });

    resultsBox.addEventListener('click', function(e){
      var item = e.target.closest('.sr-item');
      if(!item) return;
      goToResult(item.getAttribute('data-page'), item.getAttribute('data-id'), searchInput.value.trim());
    });

    document.addEventListener('click', function(e){
      if(e.target !== searchInput && !resultsBox.contains(e.target)) resultsBox.hidden = true;
    });

    // Landed here from a cross-page search result -- highlight the match once the page loads
    var pending = null;
    try{ pending = JSON.parse(sessionStorage.getItem('pendingHighlight') || 'null'); }catch(e){}
    if(pending && location.hash === '#' + pending.id){
      var pendingTarget = document.getElementById(pending.id);
      if(pendingTarget) flashHighlight(pendingTarget, pending.q);
      sessionStorage.removeItem('pendingHighlight');
    }
  }
})();
