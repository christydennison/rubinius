class Exception
  def initialize(message = nil)
    ctx = MethodContext.current.sender.sender
    # puts "EXCEPTION: #{ctx}"
    put 0, message
    put 1, ctx
  end
  
  def backtrace
    bk = at(1)
    if MethodContext === bk
      bk = Backtrace.backtrace(bk)
      self.put 1, bk
    end
    
    return bk
  end
  
  def message
    at(0)
  end
end

class ScriptError < Exception
end

class NotImplementedError < Exception
end

