require_relative 'command_line'

BuildLabels::CommandLine::COMMANDS[:cache] = Class.new do
  def options(parser)
    parser.on('', '--cache-from CACHE FROM', 'type=[local,registry] ... ')
    parser.on('', '--cache-to CACHE TO', 'type=[local,registry] ...')
  end
  def run(builder, params, compose)
    compose['services'].each do |service_name, service|
      next unless service['build']

      service['build'] = { 'context' => service['build'] } if service['build'].is_a?(String)

      image = service['image'].split(':').first
      cache_from = params[:'cache-from'] || "type=registry,ref=#{image}:cache"
      cache_to = params[:'cache-to'] || "type=registry,ref=#{image}:cache,mode=max"

      service['build']['cache_from'] = [format(cache_from, image: image, service_name: service_name)]
      service['build']['cache_to'] = [format(cache_to, image: image, service_name: service_name)]
    end
    #        - type=local,src=./.cache
    #        - type=local,dest=./.cache,mode=max
  end

  def help = 'Add cache section'
end.new


