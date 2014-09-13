var NotificationEvent = {
  events: {},
  listen: function(hash){
    for(var type in this.events){
      var el = this.events[type];
      if(el.socket)el.socket.disconnect();
      el.socket = null;
      if(el.listeners.length == 0)delete this.events[type];
    }
    for(var type in hash){
      var obj = hash[type];
      var el = this.events[type];
      if(!el)el = this.events[type] = new NotificationElement();
      el.connectData(obj.key, obj.data)
    }
  },
  parseArguments: function(arguments){
    var patterns = [];
    for(var i=0;i<arguments.length-1;i++)patterns[i]=arguments[i];
    var func = arguments[arguments.length-1];
    var first_pattern = patterns[0].split('.');
    var type = first_pattern.shift();
    patterns[0] = first_pattern.join('.');
    return {type: type, listener: {patterns: patterns, func: func}};
  },
  on: function(){
    var data = this.parseArguments(arguments);
    var el = this.events[data.type];
    if(!el)el = this.events[data.type] = new NotificationElement();
    el.on(data.listener);
  },
  off: function(){
    var data = this.parseArguments(arguments);
    var el = this.events[data.type];
    if(!el)return;
    el.off(data.listener)
    if(el.listeners.length == 0 && el.socket == null)delete this.events[data.type];
  }
}

function NotificationElement(){
  this.listeners = [];
};
NotificationElement.prototype = {
  on: function(listener){
    this.listeners.push(listener);
  },
  off: function(listener){
    this.listeners = this.listeners.filter(function(l){
      return l.patterns.join('/') != listener.patterns.join('/') || l.func != listener.func
    });
  },
  connectData: function(key, data){
    this.disconnect();
    this.data = data;
    this.socket = new IOSocket('/notification', key);
    this.socket.ondata = this.ondata.bind(this);
  },
  disconnect: function(){
    this.data=null;
    if(this.socket)this.socket.disconnect();
    this.socket = null;
  },
  applyRootChange: function(data, changes){
    if(data){
      for(var i in data){
        changes[i]=[i];
        this.data[i] = data[i];
      }
    }else{
      for(var i in this.data){
        changes[i]=[i];
        this.data[i] = null;
        delete this.data[i];
      }
    }
  },
  applyChildChange: function(keys, data, prev, changes){
    var odata = this.data;
    var pdata = prev;
    var key;
    for(var i=0;i<keys.length-1;i++){
      ckey = keys.slice(0,i+1);
      changes[ckey.join('.')] = ckey;
      key = keys[i];
      odata = odata[key] = odata[key] || {}
      if(pdata){
        if(pdata[key] == odata){
          pdata[key] = {};
          for(var attr in odata){
            pdata[key][attr] = odata;
          }
        }
        pdata = pdata[key];
      }
    }
    key = keys[keys.length-1];
    if(pdata)pdata[key] = odata[key];
    changes[keys.join('.')] = keys;
    odata[key] = data;
    for(var attr in data){
      var attrkeys = keys.concat(attr)
      changes[attrkeys.join('.')]=attrkeys;
    }
    if(!data)delete odata[key];
  },
  applyChange: function(e, prev, changes, elist){
    var type = e.data.type;
    var keys = e.data.key;
    var data = e.data.data;
    if(!keys && (type == 'updated' || type == 'deleted')){
      this.applyRootChange(data, changes);
    }else if(e.data.type == 'created' || e.data.type == 'updated' || type == 'deleted'){
      this.applyChildChange(keys, data, prev, changes);
    }else if(e.data.type == 'event' && e.time == 0){
      elist.push(e.data);
    }
  },
  objGetFromKey: function(obj, keys){
    keys.forEach(function(key){
      if(obj)obj = obj[key];
    });
    return obj;
  },
  patternMatch: function(patterns, keys){
    keys = keys.slice(0);
    var matched = [];
    for(var i=0;i<patterns.length;i++){
      var pkeys = patterns[i].split('.');
      if(patterns[i]=='')pkeys=[];
      var match = [];
      while(pkeys.length){
        if(!keys[0] || (pkeys[0]!=keys[0] && pkeys[0]!='*'))return null;
        pkeys.shift();
        match.push(keys.shift());
      }
      matched.push(match);
    }
    if(keys.length)return null;
    return matched;
  },
  ondata: function(events){
    var prev = {}, changes = {}, elist = []
    for(var i in this.data){
      prev[i] = this.data[i];
    }
    var self =　this;
    events.forEach(function(e){
      self.applyChange(e, prev, changes, elist);
    });
    if(Object.keys(changes).length)changes['']=[];
    for(var id in changes){
      var keys = changes[id];
      var prevdata = this.objGetFromKey(prev, keys);
      var newdata = this.objGetFromKey(this.data, keys);
      if(JSON.stringify(prevdata) == JSON.stringify(newdata))continue;
      this.listeners.forEach(function(cb){
        var matched = self.patternMatch(cb.patterns, keys);
        if(!matched)return;
        var pdata = prev, ndata = self.data;
        var args = []
        for(var i=0;i<matched.length;i++){
          pdata = self.objGetFromKey(pdata, matched[i]);
          ndata = self.objGetFromKey(ndata, matched[i]);
          args.push(ndata);
        }
        args.push(pdata);
        var pjson = JSON.stringify(pdata)
        var njson = JSON.stringify(ndata)
        if(pjson != njson)cb.func.apply(self.data, args);
      });
    }
    elist.forEach(function(e){
      self.listeners.forEach(function(cb){
        if(cb.patterns.join('.') == e.key.join('.')){
          cb.func(e.data);
        }
      })
    })
  },
}




