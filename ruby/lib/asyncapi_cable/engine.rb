# Required rather than assumed: a generation subprocess requires this gem
# before the host boots Rails, and the host's routes reference
# AsyncapiCable::Engine — so skipping the class definition when Rails happens
# not to be loaded yet leaves it permanently undefined.
require "rails"
require "rails/engine"

module AsyncapiCable
  class Engine < ::Rails::Engine
    isolate_namespace AsyncapiCable

    config.after_initialize do
      if defined?(ActionCable::Server::Broadcasting)
        ActionCable::Server::Broadcasting.prepend(AsyncapiCable::Runtime::ChannelHook)
      end
    end
  end
end
