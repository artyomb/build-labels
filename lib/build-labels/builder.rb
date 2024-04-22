# frozen_string_literal: true
require 'yaml'
require 'ostruct'
require 'pp'
module BuildLabels

  class Builder

    def add_namespace(name, path, labels=[])
      @namespaces ||= {}
      @namespaces[path] = OpenStruct.new
      self.class.send :define_method, name, -> { @namespaces[path] }
    end

    def initialize
      # https://github.com/opencontainers/image-spec/blob/v1.0.1/annotations.md
      add_namespace :oc, 'org.opencontainers.image', [
        :vendor, :authors, :revision, :source, :documentation, :licenses, :url,
        :version, :'ref.name', :title, :description, :created
      ]
    end

    def generate_label_schema
      # Label Schema compatibility
      add_namespace :ls, 'org.label-schema'
      self.ls['build-date'] = self.oc.created
      self.ls.url = self.oc.url
      self.ls['vcs-url'] = self.oc.source
      self.ls.version = self.oc.version
      self.ls['vcs-ref'] = self.oc.revision
      self.ls.vendor = self.oc.vendor
      self.ls.name = self.oc.title
      self.ls.description = self.oc.description
      self.ls.usage = self.oc.documentation
      self.ls['schema-version'] = '1.0'
    end

    def apply_environment
      @namespaces.each do |ns, struct|
        struct.each_pair do |name, value|
          value.sub!( /^.*$/, `printf #{value}`) if value.to_s =~ /\$/
        end
      end
    end

    def each_labels
      generate_label_schema
      apply_environment
      @namespaces.each do |ns, values|
        yield ns, values
      end
    end

    def extend_compose(compose_text)
      compose = YAML.load compose_text
      compose['services'].each do |name, service|
        next unless service['build']
        if service['build'].class == String
          service['build'] = { 'context' => service['build'] }
        end
        service['build']['labels'] ||= []
        add_namespace :dc, 'docker.service'
        self.dc.name = name

        each_labels do |ns, values|
          values.each_pair do |k,v|
            service['build']['labels'] << "#{ns}.#{k}=#{v}" unless v.to_s.empty?
          end
        end
      end
      puts compose.to_yaml
    end
  end

end

