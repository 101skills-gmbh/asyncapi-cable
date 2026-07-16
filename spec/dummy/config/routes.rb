Rails.application.routes.draw do
  mount AsyncapiCable::Engine => "/asyncapi_cable"
end
