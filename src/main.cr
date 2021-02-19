require "./runtime/lambda"
require "./usecase"

ServerlessLambda.handler "github_notifications_slack" do |event|
  uc = Usecase.new
  begin
    uc.check_notifications
  rescue err
    uc.error err
    raise err
  end
end
