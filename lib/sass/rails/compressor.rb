Sprockets.module_eval do

  #  Compresses the CSS using sassc library.
  #
  class SasscCompressor < Tilt::Template

    self.default_mime_type = 'application/javascript'

    def self.engine_initialized?
      defined?(::SassC::Engine)
    end

    def initialize_engine
      require_template_library 'sassc'
    end

    def prepare
    end

    def evaluate(context, locals, &block)
      sass_config = {
        output_style: "compressed",
        source_comments: "none"
      }

      ::SassC::Engine.new(data, sass_config).render
    end

  end

  register_compressor 'text/css', :sassc, SasscCompressor
end