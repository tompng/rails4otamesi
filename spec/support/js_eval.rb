module JSEval
  JSCODE = <<CODE
var sock;
function IOSocket(){sock = this};
NotificationEvent.listen({root: {key: 'aaa', data: data}});
sock.ondata(events);
var out = NotificationEvent.events.root.data;
console.log(JSON.stringify(out))
CODE
  class << self
    def eval_notification data, events
      events = events.select{|a,b|Model::Root === a}
      code = [
        File.read(Rails.root.join *%w(lib assets javascripts notification.js)),
        "var data = #{data.to_json}",
        "var events = #{events.map{|r,d|{data: d}}.to_json}",
        JSCODE
      ].join "\n"
      eval code
    end
    def eval code
      data = IO.popen(['node', '-e', code], &:read)
      begin
        JSON.parse data
      rescue
        data
      end
    end
  end
end





