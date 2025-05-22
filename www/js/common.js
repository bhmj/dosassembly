var nsTmpl = (
  function() {
    let cache = {};
    function base (str, _global, data, _index) {
      var strng =
            "var _p=[],print=function(){_p.push.apply(_p,arguments);};" +
            "with(obj){_p.push('" +
            str
            .replace(/[\r\t\n]/g," ")
            .replace(/^\s+</g,"<")
            .replace(/>\s+$/g,">")
            .replace(/>\s+</g,"><")
            .replace(/'(?=[^%]*%>)/g,"\t")
            .split("'").join("\\'")
            .split("\t").join("'")
            .replace(/<%=(.+?)%>/g, "',$1,'")
            .split("<%").join("');")
            .split("%>").join("_p.push('")
            + "');}return _p.join('');"
      ;
//      var fn = !/\W/.test(str) ?
//        this.cache[str] = this.cache[str] || this.tmpl(document.getElementsByClassName(str)[0].innerHTML) : new Function("obj",strng);
//      if (data) return fn(data);
//      return data ? fn(data) : fn;
      // debug mode
      var fn;
      if (!/[^\w-]/.test(str)) {
        if (cache[str]) {
          fn = cache[str];
        } else {
          var arr = document.getElementsByClassName(str);
          if (!arr.length) throw "Template not found: \""+str+"\"";
          var a = arr[0].innerHTML;
          fn = base(a);
          cache[str] = fn;
        }
      } else {
        fn = new Function("_global", "obj", "_index", strng);
      }
      return data ? fn(_global, data, _index) : fn;
    };

    return {
      // simple template with _index
      tmpl : function (template_name, data, _index) {
        return base(template_name, {}, data, _index);
      },

      // template with global data and _index
      tmplx : function (template_name, global, data, _index)
      {
        return base(template_name, global, data, _index);
      },

      // array template: call simple template for each array element
      tmplr : function (template_name, arr)
      {
        let s="";
        for (var i=0; i<(arr ? arr.length : 0); i++)
          s += this.tmpl(template_name, arr[i], i);
        return s;
      },

      // array template with global data: call array template for each array element
      tmplrx : function (template_name, global, arr)
      {
        let s="";
        for (var i=0; i<(arr ? arr.length : 0); i++)
          s += this.tmplx(template_name, global, arr[i], i);
        return s;
      }
    }
  }
)();
