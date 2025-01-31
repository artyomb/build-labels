require_relative 'command_line'

BuildLabels::CommandLine::COMMANDS[:set_version] = Class.new do

  def run(_builder, params, compose)
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

      current_version = File.exist?( version_file) ? File.read(version_file).strip : nil

      svc['build']['tags'] = svc['build']['tags'].map do |t|
        image, tag = t.split(':')
        full_tag = [current_version, tag].compact.join('-')

        [image, full_tag].compact.join ':'
      end

      if ENV['CI_COMMIT_MESSAGE'].to_s =~ /#push/mi
        full_version = "#{current_version.to_s.empty? ? '0.0' : current_version}.#{ENV['CI_PIPELINE_IID']}"

        push_tag = ENV['CI_COMMIT_MESSAGE'].to_s[/#push:(.+?)/mi, 1]

        svc['build']['tags'] += svc['build']['tags'].map do |t|
          image, tag = t.split(':')
          full_tag = [full_version, push_tag || tag].compact.join('-')

          [image, full_tag].compact.join ':'
        end
      end

    end
  end

  def help
    'Add version tag from [docker_context]/.version file to image'
  end
end.new
