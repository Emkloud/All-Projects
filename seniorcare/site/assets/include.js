(function(){
  function inject(id, url){
    var el = document.getElementById(id);
    if(!el) return;
    fetch(url, {cache: 'no-cache'})
      .then(function(r){ return r.text(); })
      .then(function(html){ el.innerHTML = html; })
      .catch(function(){ el.innerHTML = ''; });
  }
  document.addEventListener('DOMContentLoaded', function(){
    inject('header', '/partials/header.html');
    inject('footer', '/partials/footer.html');
  });
})();
