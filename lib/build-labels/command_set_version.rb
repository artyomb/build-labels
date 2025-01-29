require_relative 'command_line'

BuildLabels::CommandLine::COMMANDS[:set_version] = Class.new do
  # def options(parser)
  #   parser.on('', '--set-version', '')
  # end

  def apply_gitlab_tag(tag)
    return tag if ENV['CI_COMMIT_TAG'].to_s.empty?
    git_tag = ENV['CI_COMMIT_TAG']
    [tag,git_tag].compact.join '-'
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
      image = svc['image'].gsub( /:.*/, '')
      tag = svc['image'][/:(.*)/, 1]

      tag = apply_gitlab_tag(tag)
      full_tag = [current_version, tag].compact.join '-'
      full_tag = full_tag.empty? ? '' : ":#{full_tag}"

      svc['image'] = "#{image}#{full_tag}"

      next unless svc['build']['tags']
      svc['build']['tags'] = svc['build']['tags'].map do |t|
        image = t.gsub( /:.*/, '')
        tag = t[/:(.*)/, 1]
        tag = apply_gitlab_tag(tag)

        full_tag = [current_version, tag].compact.join '-'
        full_tag = full_tag.empty? ? '' : ":#{full_tag}"

        "#{image}#{full_tag}"
      end
    end

  end

  def help = 'Add version tag from [docker_context]/.version file to image'
end.new


