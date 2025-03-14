require_relative '../version'
require 'optparse'
# frozen_string_literal: true
require_relative '../build-labels/yaml_merge'

module HelmPush
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
            'helm-push -c docker-compose.yml -version-mask=\d+\.\d+\.\d+',
            'cat docker-compose.yml | helm-push',
            'helm-push < docker-compose.yml'
          ]
          o.banner = "Version: #{o.version}\nUsage:\n\t#{usage.join "\n\t"}"
          o.separator ''
          o.separator 'Commands:'
          COMMANDS.each { |name, cmd| o.separator "#{' ' * 5}#{name} -  #{cmd.help}" }

          o.separator ''
          o.separator 'Options:'

          #  in all caps are required
          o.on('-c', '--compose COMPOSE_FILE', 'Compose file')
          o.on('-m', '--version-mask VERSION_MASK', 'Version mask')
          o.on('-e', '--env FILE', 'Load .build_info FILE') { load_env _1 }
          o.on('-n', '--no-env', 'Do not process env variables') { true }
          COMMANDS.values.select{_1.options(o) if _1.respond_to? :options }

          o.on('-h', '--help') { puts o; exit }
          rest = o.parse! args, into: params


          compose_text = File.read(params[:compose]) if params[:compose]
          compose_text ||= STDIN.read unless $stdin.tty?

          result = YamlMerge.parse_and_process_yaml compose_text
          compose_text = YamlMerge.deep_copy_without_aliases result

          #  eval $(grep -v -e '^#' .build_info | xargs -I {} echo export \'{}\') && echo $CI_COMMIT_AUTHOR
          rest = ['push'] if rest.empty?

          rest.each do |command|
            raise "Unknown command: #{command}" unless COMMANDS.key?(command.to_sym)
            COMMANDS[command.to_sym].run params, compose_text
          end
        rescue => e
          puts e.message
          exit 1
        end
      end
    end
  end
end
