require "./usecase.cr"

class Worker
  def initialize
  end

  def run
    loop do
      exec
      sleep 60
    end
  end

  def exec
    uc = Usecase.new

    begin
      uc.check_notifications
    rescue err
      uc.error err
    end
  end
end
