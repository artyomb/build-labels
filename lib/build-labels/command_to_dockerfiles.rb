require_relative 'command_line'

BuildLabels::CommandLine::COMMANDS[:to_dockerfiles] = Class.new do
  def run(builder, params, compose)
    raise 'Compose file not defined' unless compose
    compose_dir = params[:compose] ? File.dirname(params[:compose]) : '.'


    compose['services'].each do |name, svc|
      next unless svc['build']

      dockerfile = svc['build'].is_a?(String) ? svc['build'] : svc['build']['context']
      dockerfile = File.join dockerfile, (svc['build']['dockerfile'] || 'Dockerfile')
      dockerfile = File.expand_path dockerfile, compose_dir
      raise "file not found: #{dockerfile}" unless File.exist? dockerfile

      dockerfile_lines = File.readlines(dockerfile).map(&:rstrip)

      builder.each_labels do |ns, values|
        values.each_pair do |k, v|
          next if v.to_s.empty?

          name = "#{ns}.#{k}".gsub('.', '_').upcase
          line = %Q(ENV #{name}=#{v.inspect})
          dockerfile_lines.push line unless dockerfile_lines.grep(/ENV\s+#{name}=/).any?
        end
      end
      File.write dockerfile, dockerfile_lines.join("\n")
    end
  end

  def help = 'Add ENVs to Dockerfiles from docker-compose file'
end.new


