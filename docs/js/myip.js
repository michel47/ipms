
var url='https://api.ipify.org/?format=json';
getj(url);

function getj(url) {
   fetch(url)
      .then( resp => resp.json() )
      .then( function(obj) {
         var elems = document.getElementsByClassName('ip');
         for(var i=0; i<elems.length; i++) {
            if (typeof elems[i].href != 'undefined') {
            elems[i].href = 'http://'+ obj['ip'] +'/';
            }
            elems[i].innerHTML = obj['ip'];

         }
      })
      .catch(e => console.log(e));
}


