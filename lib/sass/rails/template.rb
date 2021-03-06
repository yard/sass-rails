require "sprockets/sass_template"
require "base64"

module Sprockets
  class SassTemplate
    
    def evaluate(context, locals, &block)
      cache_store = SassCacheStore.new(context.environment)

      options = {
        :filename => eval_file,
        :line => line,
        :syntax => syntax,
        #:cache_store => cache_store,
        #:importer => SassImporter.new(context, context.pathname),
        #:load_paths => context.environment.paths.map { |path| SassImporter.new(context, path) },
        :sprockets => {
          :context => context,
          :environment => context.environment
        }
      }

      sass_config = context.environment.context_class.sass_config.merge(options)

      engine = ::SassC::Engine.new(data, sass_config)
      
      engine.custom_function(:resolve_imports) do |args|
        cwd, path = args[0], args[1]
        resolve_imports(context: context, cwd: cwd, path: path)
      end

      %w(asset-path asset-url image-path image-url video-path video-url audio-path audio-url font-path font-url javascript-path javascript-url stylesheet-path stylesheet-url).each do |name|
        engine.custom_function("#{ name }($arg)") do |args|
          result = context.send(name.gsub("-", "_"), unqoute_argument(args.first))
          name.include?("-url") ? "url('#{result}')" : result
        end
      end

      engine.custom_function("base64-encode($arg)") do |args|
        arg = unqoute_argument(args.first)
        Base64.encode64(arg).gsub(/[\r\n]/, "")
      end

      engine.custom_function("twbs-font-path($arg)") do |arg|
        context.font_path(unqoute_argument(args.first))
      end

      engine.render
    rescue ::Sass::SyntaxError => e
      context.__LINE__ = e.sass_backtrace.first[:line]
      raise e
    end

    #  Unqoutes the argument.
    #
    def unqoute_argument(arg)
      if arg.size > 0
        arg = arg[1..-1]  if (arg.first == "\"") || (arg.first == "\'") 
        arg = arg[0...-1] if (arg.last == "\"")  || (arg.last == "\'") 
      end

      arg
    end

    #  Resolves the import string taking into account current working directory.
    #
    #  The options to take into considerations are:
    #  1) Import might be wildcard – this way, multiple files would match.
    #  2) Import might be relative, and, unfortunatelly, there is no way to know it upfront
    #  3) Import might require looking for underscored name – just like Rails partials.
    #
    def resolve_imports(options = {})
      cwd       = options[:cwd]
      path      = options[:path]
      context   = options[:context] 

      path = path[1..-1] if path.start_with?(".")

      @@cache ||= {}

      @@cache[ path ] ||= begin
        if path.end_with?("*")
          resolve_wildcard_import context, path, cwd
        else
          resolve_specific_import context, path, cwd
        end
      end

      @@cache[ path ].each do |path|
        context.depend_on(path)
      end
    end

  protected

    #  Resolves an import statement containing "*".
    #
    def resolve_wildcard_import(context, path, cwd)
      trail = context.environment.instance_variable_get(:@trail)
      pathnames = []

      _path = File.join(cwd, path)
      trail.entries(_path[0...-1]).each do |candidate|
        candidate = _path.gsub("*", candidate.to_s)
        pathnames << candidate if "text/css" == context.environment.content_type_of(candidate)  
      end if pathnames.blank?

      _path = File.join(cwd, path).gsub(/.+\/assets\/stylesheets\//, "")
      trail.entries(_path[0...-1]).each do |candidate|
        candidate = _path.gsub("*", candidate.to_s)
        pathnames << candidate if "text/css" == context.environment.content_type_of(candidate)  
      end if pathnames.blank?

      _path = path
      trail.entries(_path[0...-1]).each do |candidate|
        candidate = _path.gsub("*", candidate.to_s)
        pathnames << candidate if "text/css" == context.environment.content_type_of(candidate)  
      end if pathnames.blank?

      pathnames
    end

    #  Resolves specific import.
    #
    def resolve_specific_import(context, path, cwd)
      trail = context.environment.instance_variable_get(:@trail)
      pathnames = []

      _path = File.join(cwd, path)
      trail.find(_path) do |candidate|
        pathnames << candidate if "text/css" == context.environment.content_type_of(candidate)  
      end if pathnames.blank?

      _path = File.join(cwd, path)
      trail.find((_path.split("/")[0...-1] + [ "_" + _path.split("/")[-1] ]).join("/")) do |candidate|
        pathnames << candidate if "text/css" == context.environment.content_type_of(candidate)  
      end if pathnames.blank?

      _path = File.join(cwd, path).gsub(/.+\/assets\/stylesheets\//, "")
      trail.find(_path) do |candidate|
        pathnames << candidate if "text/css" == context.environment.content_type_of(candidate)  
      end if pathnames.blank?

      _path = File.join(cwd, path).gsub(/.+\/assets\/stylesheets\//, "")
      trail.find((_path.split("/")[0...-1] + [ "_" + _path.split("/")[-1] ]).join("/")) do |candidate|
        pathnames << candidate if "text/css" == context.environment.content_type_of(candidate)  
      end if pathnames.blank?

      _path = path
      trail.find(_path) do |candidate|
        pathnames << candidate if "text/css" == context.environment.content_type_of(candidate)  
      end if pathnames.blank?

      _path = path
      trail.find((_path.split("/")[0...-1] + [ "_" + _path.split("/")[-1] ]).join("/")) do |candidate|
        pathnames << candidate if "text/css" == context.environment.content_type_of(candidate)  
      end if pathnames.blank?

      pathnames = pathnames[0 .. 0]
    end

  end

end
