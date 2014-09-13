module NodeNotification
  class << self
    def notify arg
      key = arg[:key]
      data = arg[:data]
      events << ["#{key.class.name}##{key.id}",data]
    end

    def clear
      @events = []
    end

    def events
      @events ||= []
    end

  end
end