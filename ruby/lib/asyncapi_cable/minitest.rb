require "asyncapi_cable"
require_relative "adapters/minitest"

AsyncapiCable::Adapters::Minitest.install!
