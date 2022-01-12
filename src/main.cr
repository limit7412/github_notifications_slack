require "./runtime/lambda"
require "./notify/usecase"
require "./error/usecase"

Serverless::Lambda.handler "github_notifications_slack" do |event|
  begin
    notify_uc = Notify::Usecase.new
    notify_uc.check_notifications
  rescue err
    err_uc = Error::Usecase.new
    err_uc.alert err
    raise err
  end
end
