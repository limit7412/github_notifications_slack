require "./usecase.cr"

class App
  def initialize
  end

  def run
    uc = Usecase.new

    begin
      uc.check_notifications
    rescue err
      uc.error err
    end
  end
end
