require_relative 'command_line'

BuildLabels::CommandLine::COMMANDS[:changed] = Class.new do
  def options(parser)
    parser.on('', '--changes-compose FOLDER', 'docker-compose path ... ')
  end

  def run(builder, params, compose)
    dc_folder = params[:'changes-compose'] || Dir.pwd
    $stderr.puts "Changes Compose: #{dc_folder}, CI_COMMIT_BEFORE_SHA: #{ENV['CI_COMMIT_BEFORE_SHA']}, CI_COMMIT_SHA: #{ENV['CI_COMMIT_SHA']}"

    compose['services'].each do |service_name, service|
      next unless service['build']
      $stderr.puts "Checking #{service_name} for changes ..."

      ad = service.dig('build','additional_contexts') || []
      ad = ad.class == Hash ? ad.values : ad.map{_1[/=(.*)/,1]}
      contexts = [service.dig('build','context')] + ad
      contexts = contexts.flatten.compact.map{File::absolute_path(dc_folder + '/' + _1) + '/' }
      contexts << File::absolute_path(service.dig('build','dockerfile'))


      should_build = contexts.any? do |path|
        $stderr.puts "Checking #{path} for changes..."
        Dir.chdir path do
          files = `git diff --name-only $CI_COMMIT_BEFORE_SHA $CI_COMMIT_SHA`.split("\n").map(&:strip).delete_if(&:empty?)

          if files.any?
            $stderr.puts "changes found:"
            files[0..3].each{ $stderr.puts "\t#{_1}" }
            next true
          else
            false
          end
        end
      end

      $stderr.puts "should_build: #{should_build}"

      service.delete 'build' unless should_build
    end

  end

  def help = 'Detect git changes and filter compose service list'
end.new


