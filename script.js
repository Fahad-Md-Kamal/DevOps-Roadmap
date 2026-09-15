(function(){
  var expandAll = document.getElementById('expand-all');
  var collapseAll = document.getElementById('collapse-all');
  function allDetails(){ return document.querySelectorAll('main details'); }
  if(expandAll) expandAll.addEventListener('click', function(){ allDetails().forEach(function(d){ d.open = true; }); });
  if(collapseAll) collapseAll.addEventListener('click', function(){ allDetails().forEach(function(d){ d.open = false; }); });

  document.querySelectorAll('.nav a[href^="#"]').forEach(function(a){
    a.addEventListener('click', function(e){
      var id = a.getAttribute('href').slice(1);
      var target = document.getElementById(id);
      if(!target) return;
      var details = target.closest('details');
      while(details){ details.open = true; details = details.parentElement.closest('details'); }
      if(target.tagName === 'DETAILS') target.open = true;
    });
  });

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
})();
