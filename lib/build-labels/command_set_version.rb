require_relative 'command_line'

BuildLabels::CommandLine::COMMANDS[:set_version] = Class.new do
  def commit_message_commands(version)
    return version unless (match = ENV['CI_COMMIT_MESSAGE']&.match(/#push:(\w+)/i))

    puts 'Debug: Push command detected in commit message'
    version = '0.0' if version.to_s.empty?
    tag = match[1] ? "-#{match[1]}" : ''
    "#{version}.#{ENV['CI_PIPELINE_IID']}#{tag}"
  end

  def run(builder, params, compose)
    raise 'Compose file not defined' unless compose

    compose_dir = params[:compose] ? File.dirname(params[:compose]) : '.'

    compose['services'].each do |name, svc|
      next unless svc['build']
      versionfile = svc['build'].is_a?(String) ? './' : svc['build']['context']
      versionfile = File.join versionfile, '.version'
      versionfile = File.expand_path versionfile, compose_dir

      current_version = File.exist?( versionfile) ? File.read(versionfile).strip : nil
      current_version = commit_message_commands(current_version)

      image = svc['image'].gsub( /:.*/, '')
      tag = svc['image'][/:(.*)/, 1]

      full_tag = [current_version, tag].compact.join '-'
      full_tag = full_tag.empty? ? '' : ":#{full_tag}"

      svc['image'] = "#{image}#{full_tag}"

      next unless svc['build']['tags']
      svc['build']['tags'] = svc['build']['tags'].map do |t|
        image, tag = t.split(':')
        full_tag = [current_version, tag].compact.join('-')
        "#{image}#{full_tag.empty? ? '' : ":#{full_tag}"}"
      end
    end
  end

  def help
    'Add version tag from [docker_context]/.version file to image'
  end
end.new