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
