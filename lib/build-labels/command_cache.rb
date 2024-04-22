require_relative 'command_line'

BuildLabels::CommandLine::COMMANDS[:cache] = Class.new do
  def run(builder, params, compose_text)
    compose = YAML.load compose_text
    compose['services'].each do |name, service|
      next unless service['build']

      if service['build'].class == String
        service['build'] = { 'context' => service['build'] }
      end
      # registry = params[:registry]
      image = service['image'].gsub( /:.*/, '')
      service['build']['cache_from'] = [ "type=registry,ref=#{image}:cache" ]
      service['build']['cache_to'] = [ "type=registry,ref=#{image}:cache,mode=max" ]
      # #        - type=local,src=./.cache
      # #        - type=local,dest=./.cache,mode=max
    end
    compose_text.replace compose.to_yaml
  end

  def help = 'Add cache section'
end.new


