require "./usecase.cr"

class App
  def initialize
  end

  def run
    uc = Usecase.new

    begin
      puts "仲間だもんげ"
    rescue err
      uc.error err
    end
  end
end
