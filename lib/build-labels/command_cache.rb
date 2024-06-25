require_relative 'command_line'

BuildLabels::CommandLine::COMMANDS[:cache] = Class.new do
  def options(parser)
    parser.on('', '--cache-from CACHE FROM', 'type=[local,registry] ... ')
    parser.on('', '--cache-to CACHE TO', 'type=[local,registry] ...')
  end
  def run(builder, params, compose_text)
    compose = YAML.load compose_text
    compose['services'].each do |service_name, service|
      next unless service['build']

      if service['build'].class == String
        service['build'] = { 'context' => service['build'] }
      end
      # p params
      # registry = params[:registry]
      image = service['image'].gsub( /:.*/, '')
      if params[:'cache-from']
        service['build']['cache_from'] = [ params[:'cache-from'] % {image: image, service_name: service_name} ]
      else
        service['build']['cache_from'] = [ "type=registry,ref=#{image}:cache" ]
      end

      if params[:'cache-to']
        service['build']['cache_to'] = [ params[:'cache-to'] % {image: image, service_name: service_name} ]
      else
        service['build']['cache_to'] = [ "type=registry,ref=#{image}:cache,mode=max" ]
      end
      # #        - type=local,src=./.cache
      # #        - type=local,dest=./.cache,mode=max
    end
    compose_text.replace compose.to_yaml
  end

  def help = 'Add cache section'
end.new


