require_relative '../version'
require 'optparse'

module BuildLabels
  module CommandLine
    COMMANDS = {}

    class << self
      def load_env(filename)
        File.read(filename).lines.map(&:strip).grep_v(/^\s*#/).reject(&:empty?)
          .map {
           if _1 =~ /([^=]+)=(.*)/
              a, k,v = Regexp.last_match.to_a
              ENV[k] = v
              [k,v]
            else
              nil
            end
          }.compact.to_h
       rescue =>e
         puts "Load env error: #{e.message}"
         raise "Invalid #{filename} file"
      end

      def run(args)
        params = {}

        ARGV << '-h' if ARGV.empty?
        OptionParser.new do |o|
          o.version = "#{BuildLabels::Builder::VERSION}"

          usage = [
            'build-labels -c docker-compose.yml gitlab',
            'cat docker-compose.yml | build-labels gitlab',
            'build-labels gitlab < docker-compose.yml'
          ]
          o.banner = "Version: #{o.version}\nUsage:\n\t#{usage.join "\n\t"}"
          o.separator ''
          o.separator 'Commands:'
          COMMANDS.each { |name, cmd| o.separator "#{' ' * 5}#{name} -  #{cmd.help}" }

          o.separator ''
          o.separator 'Options:'

          #  in all caps are required
          o.on('-c', '--compose COMPOSE_FILE', 'Compose file')
          o.on('-e', '--env FILE', 'Load .build_info FILE') { load_env _1 }
          o.on('-n', '--no-env', 'Do not process env variables') { true }
          o.on('-h', '--help') { puts o; exit }
          o.parse! args, into: params

          raise 'Compose file not defined' if $stdin.tty? && !params[:compose]

          command = args.shift || ''
          raise "Unknown command: #{command}" unless COMMANDS.key?(command.to_sym)

          compose_text = File.read(params[:compose]) if params[:compose]
          compose_text ||= STDIN.read unless $stdin.tty?

          builder = Builder.new
          COMMANDS[command.to_sym].run builder, params
          #  eval $(grep -v -e '^#' .build_info | xargs -I {} echo export \'{}\') && echo $CI_COMMIT_AUTHOR

          builder.extend_compose compose_text
        rescue => e
          puts e.message
          exit 1
        end
      end
    end
  end
end
