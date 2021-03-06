module Panoramic
  class Resolver < ActionView::Resolver
    require "singleton"
    include Singleton

    # this method is mandatory to implement a Resolver
    def find_templates(name, prefix, partial, details, key=nil, locals=[])
      return [] if @resolver_options[:only] && !@resolver_options[:only].include?(prefix)

      conditions = {
        :path    => build_path(name, prefix),
        :locale  => [normalize_array(details[:locale]).first, nil],
        :format  => normalize_array(details[:formats]),
        :handler => normalize_array(details[:handlers]),
        :partial => partial || false
      }

      @model.find_model_templates(conditions).map do |record|
        initialize_template(record)
      end
    end

    def find_all(name, prefix=nil, partial=false, details={}, key=nil, locals=[])
      if @resolver_options[:cache]
        cached(key, [name, custom_cache_prefix, prefix, partial].compact, details, locals) do
          find_templates(name, prefix, partial, details)
        end
      else
        find_templates(name, prefix, partial, details)
      end
    end

    def custom_cache_prefix
      @model.try(:custom_prefix)
    end

    # Instantiate Resolver by passing a model (decoupled from ORMs)
    def self.using(model, options={})
      self.instance.using(model, options)
    end

    def using(model, options={})
      @model = model
      @resolver_options = options
      self
    end

    private

    # Initialize an ActionView::Template object based on the record found.
    def initialize_template(record)
      source = record.body
      identifier = "#{record.class} - #{record.id} - #{record.path.inspect}"
      handler = ActionView::Template.registered_template_handler(record.handler)

      details = {
        :format => Mime[record.format],
        :updated_at => record.updated_at,
        :virtual_path => virtual_path(record.path, record.partial)
      }

      ActionView::Template.new(source, identifier, handler, details)
    end

    # Build path with eventual prefix
    def build_path(name, prefix)
      prefix.present? ? "#{prefix}/#{name}" : name
    end

    # Normalize array by converting all symbols to strings.
    def normalize_array(array)
      array.map(&:to_s)
    end

    # returns a path depending if its a partial or template
    def virtual_path(path, partial)
      return path unless partial
      if index = path.rindex("/")
        path.insert(index + 1, "_")
      else
        "_#{path}"
      end
    end
  end
end
