AsyncapiCable::Engine.routes.draw do
  get "schemas", to: "schemas#index", as: :schemas
  get "schemas/*id", to: "schemas#show", as: :schema
end
