require_relative 'command_line'

BuildLabels::CommandLine::COMMANDS[:set_version] = Class.new do
  def options(parser)
    parser.on('', '--full-version', 'Push full version tag')
  end

  def run(builder, params, compose)
    raise 'Compose file not defined' unless compose

    compose_dir = params[:compose] ? File.dirname(params[:compose]) : '.'

    compose['services'].each do |_name, svc|
      next unless svc['build']

      unless svc['build']['tags']
        svc['build']['tags'] = [svc['image']]
      end

      version_file = svc['build'].is_a?(String) ? './' : svc['build']['context']
      version_file = File.join version_file, '.version'
      version_file = File.expand_path version_file, compose_dir

      unless File.exist?(version_file)
        puts "Version file not found: #{version_file}"
        exit 1
      end

      current_version = File.read(version_file).strip
      unless current_version =~ /\d+(\.\d+)*/
        puts "Invalid version file: #{version_file}. Expected version in format: numbers separated by dots (e.g. 1.2.3)"
        exit 1
      end

      build_id = ENV['GITHUB_RUN_NUMBER'] || ENV['CI_PIPELINE_IID']
      unless build_id
        puts "Build ID not found. Please set GITHUB_RUN_NUMBER or CI_PIPELINE_IID environment variable"
        exit 1
      end

      full_version = "#{current_version}.#{build_id}"
      builder.oc.version = full_version

      svc['build']['tags'] = svc['build']['tags'].map do |t|
        image, tag = t.split(':')
        full_tag = [current_version, tag].compact.join('-')

        [image, full_tag].compact.join ':'
      end

      if ENV['CI_COMMIT_MESSAGE'].to_s =~ /#push/mi || params[:full_version]
        push_tag = ENV['CI_COMMIT_MESSAGE'].to_s[/#push:(\S+)/mi, 1]

        svc['build']['tags'] += svc['build']['tags'].map do |t|
          image, _tag = t.split(':')
          full_tag = [full_version, push_tag].compact.join('-')

          [image, full_tag].compact.join ':'
        end
      end

      # add latest tag
      if svc['image'].split(':').size == 1
        svc['build']['tags'] << "#{svc['image']}:latest"
      end
    end
  end

  def help
    'Add version tag from [docker_context]/.version file to image'
  end
end.new
