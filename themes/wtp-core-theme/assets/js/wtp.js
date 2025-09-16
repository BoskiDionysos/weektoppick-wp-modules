(function(){
    function getCookie(name){
        var m = document.cookie.match(new RegExp('(?:^|; )'+name+'=([^;]*)'));
        return m ? decodeURIComponent(m[1]) : '';
    }
    function setCookie(name,value,days){
        var d = new Date(); d.setTime(d.getTime()+days*864e5);
        document.cookie = name+'='+encodeURIComponent(value)+';path=/;expires='+d.toUTCString();
    }

    function ready(fn){ if(document.readyState!='loading'){fn()} else {document.addEventListener('DOMContentLoaded',fn)} }

    ready(function(){
        // Toggle subchips
        document.querySelectorAll('[data-wtp-toggle]').forEach(function(btn){
            btn.addEventListener('click', function(e){
                var target = document.querySelector('[data-wtp-sub="'+btn.getAttribute('data-wtp-toggle')+'"]');
                if (!target) return;
                document.querySelectorAll('.wtp-subchips').forEach(function(sc){ if(sc!==target) sc.classList.remove('open');});
                target.classList.toggle('open');
                e.preventDefault();
            });
        });

        // Charity banner behavior
        var seen = getCookie('wtp_charity_seen') === '1';
        var banner = document.querySelector('.wtp-charity');
        if (banner){
            if (seen){
                banner.classList.remove('sticky-top');
                banner.classList.add('sticky-bottom');
                // move to bottom of content
                document.body.appendChild(banner);
            } else {
                banner.classList.add('sticky-top');
                setCookie('wtp_charity_seen','1',365);
            }
        }
    });
})();