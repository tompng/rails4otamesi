module Fixture
  def self.load
    build = ->(hash, parent=nil){
      hash.each do |name, chash|
        multiple = name =~ /many$/
        method = multiple ? name.to_s.pluralize : name
        klass = Model.const_get name.to_s.camelize
        data = {
          name: "#{name}_#{rand}",
          content: "content_#{name}_#{rand}",
          "content_#{name}" => rand
        }
        if multiple
          4.times{
            if parent
              child = parent.send(method).create data
            else
              child = klass.create data
            end
            build[chash, child]
          }
        else
          if parent
            child = parent.send "#{method}=", Model.const_get(name.to_s.camelize).new(data)
          else
            child = klass.create data
          end
          build[chash, child]
        end
      end
    }
    build[Model.structure]
  end
end

