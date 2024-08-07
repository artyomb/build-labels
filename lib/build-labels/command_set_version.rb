require_relative 'command_line'

BuildLabels::CommandLine::COMMANDS[:set_version] = Class.new do
  # def options(parser)
  #   parser.on('', '--set-version', '')
  # end

  def run(builder, params, compose)
    raise 'Compose file not defined' unless compose

    compose_dir = params[:compose] ? File.dirname(params[:compose]) : '.'

    compose['services'].each do |name, svc|
      next unless svc['build']
      versionfile = svc['build'].is_a?(String) ? './' : svc['build']['context']
      versionfile = File.join versionfile, '.version'
      versionfile = File.expand_path versionfile, compose_dir
      next unless File.exist? versionfile
      current_version = File.read(versionfile).strip
      image = svc['image'].gsub( /:.*/, '')
      tag = svc['image'][/:(.*)/, 1]
      svc['image'] = "#{image}:#{current_version}#{tag ? "-" + tag : ""}"
      next unless svc['build']['tags']
      svc['build']['tags'] = svc['build']['tags'].map do |t|
        image = t.gsub( /:.*/, '')
        tag = t[/:(.*)/, 1]
        "#{image}:#{current_version}#{tag ? "-" + tag : ""}"
      end
    end

  end

  def help = 'Add version tag from [docker_context]/.version file to image'
end.new


