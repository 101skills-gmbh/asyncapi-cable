# frozen_string_literal: true

module AsyncapiCable
  class SchemasController < ActionController::API
    def index
      schemas = AsyncapiCable.configuration.schemas.keys.map(&:to_s)
      render json: {schemas: schemas}
    end

    def show
      schema_name = params[:id]
      return head :not_found unless AsyncapiCable.configuration.schemas.key?(schema_name.to_sym)

      file_path = schema_file_path(schema_name)
      return head :not_found unless File.exist?(file_path)

      content_type = file_path.end_with?(".json") ? "application/json" : "application/x-yaml"
      render plain: File.read(file_path), content_type: content_type
    end

    private

    def schema_file_path(schema_name)
      config = AsyncapiCable.configuration
      ext = (config.schema_output_format == :json) ? "json" : "yaml"
      Rails.root.join(config.schema_output_dir, "#{schema_name}.#{ext}").to_s
    end
  end
end
