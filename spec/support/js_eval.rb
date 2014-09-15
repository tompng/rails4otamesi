module JSEval
JSCODE = <<CODE
  var sock;
  function IOSocket(){sock = this};
  NotificationEvent.listen({root: {key: 'aaa', data: data}});
  var calledEvents = {};
  Object.keys(listeners).forEach(function(key){
    var paths = listeners[key];
    paths.forEach(function(path){
      NotificationEvent.on.apply(NotificationEvent, path.concat(function(){
        var e = calledEvents[key]
        if(!e){
          e=calledEvents[key]={status:0};
          paths.forEach(function(k){e[k.join('/')]=0});
        }
        e[path.join('/')]++;
        var dups=[]
        var count=0;
        paths.forEach(function(k){
          var val = e[k.join('/')];
          if(val)count++;
          if(val>1)dups.push(k);
        })
        if(count==0)e.status=0;
        else if(count==paths.length&&dups.length==0)e.status=1;
        else{
          e.status={count: count, max: paths.length, dups: dups}
        }
      }))
    })
  })
  sock.ondata(events);
  var out = NotificationEvent.events.root.data;
  var events=[]
  var errors=[]
  Object.keys(calledEvents).forEach(function(key){
    var status = calledEvents[key].status;
    if(status==1)events.push(key);
    else errors.push([key,status]);
  })

  console.log(JSON.stringify({output: out, events: events.sort(), errors: errors}))
CODE
  def self.eval_notification data, events
    events = events.select{|a,b|Model::Root === a}
    code = [
      File.read(Rails.root.join *%w(lib assets javascripts notification.js)),
      "var data = #{data.to_json}",
      "var events = #{events.map{|r,d|{data: d}}.to_json}",
      "var listeners = #{listeners.to_json}",
      JSCODE
    ].join "\n"
    eval code
  end
  def self.eval code
    data = IO.popen(['node', '-e', code], &:read)
    begin
      JSON.parse data
    rescue
      data
    end
  end
  def self.listeners
    list = []
    rec = ->(hash, parents=nil){
      hash.each{|k,v|
        k = k.to_s
        multiple = k =~ /_many$/
        if multiple
          list << {key: k.pluralize, path: [*parents,k.pluralize]}
          list << {key: k, path: [*parents,k.pluralize,'*']}
          list << {key: "#{k}_name", path: [*parents,k.pluralize,'*', 'name']}
          rec[v, [*parents,k.pluralize,'*']]
        else
          list << {key: k, path: [*parents,k]}
          list << {key: "#{k}_name", path: [*parents,k, 'name']}
          rec[v, [*parents,k]]
        end
      }
    }
    rec[Model.structure]
    list.map{|kp|
      key, path = kp[:key], kp[:path]
      [key,[false, true].repeated_permutation(path.length-1).map{|joints|
        out = []
        p = path.dup
        out = [p.shift]
        joints.each{|j|
          if j
            out[-1] = [out[-1], p.shift].join '.'
          else
            out << p.shift
          end
        }
        out
      }]
    }.to_h
  end
end





