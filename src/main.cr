require "./runtime/lambda"
require "./notify/usecase"
require "./error/usecase"

Serverless::Lambda.handler "github_notifications_slack" do |event|
  begin
    notifyUC = Notify::Usecase.new
    notifyUC.check_notifications
  rescue err
    errUC = Error::Usecase.new
    errUC.error err
    raise err
  end
end
