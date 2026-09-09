require 'json'
require 'open3'
require 'optparse'
require 'shellwords'
require 'yaml'
require_relative 'version'

class TrivyRunner
  IMAGE_ID = /\Asha256:[0-9a-f]{64}\z/

  def run(args)
    file = 'bake.yml'
    metadata_file = nil
    tty = true
    parser = OptionParser.new do |options|
      options.banner = 'Usage: trivy-runner -f BAKE_FILE --metadata-file FILE [TARGET/GROUP ...] [-- TRIVY_OPTIONS ...]'
      options.separator 'Options after -- are forwarded to trivy image.'
      options.on('-f', '--file FILE', 'Bake or Compose file (default: bake.yml)') { file = _1 }
      options.on('--metadata-file FILE', 'Buildx metadata from the local build') { metadata_file = _1 }
      options.on('--image-src SOURCE', %w[docker], 'Image source (default: docker)')
      options.on('--[no-]tty', 'Enable terminal output and Trivy table colors (default: enabled)') { tty = _1 }
      options.on('-v', '--version', 'Print version') { puts BuildLabels::Builder::VERSION; return 0 }
      options.on('-h', '--help', 'Print help') { puts options; return 0 }
    end
    separator = args.index('--') || args.length
    trivy_args = args.drop(separator + 1)
    targets = parser.parse!(args.take(separator))
    raise OptionParser::MissingArgument, '--metadata-file' unless metadata_file
    return 0 if targets.empty? && empty_compose?(file)

    metadata = JSON.parse(File.read(metadata_file))
    plan = capture_json('docker', 'buildx', 'bake', '-f', file, '--print', '--', *targets)
    images = image_tags(plan.fetch('target'), metadata)
    return 0 if images.empty?

    verify_images(images)
    images.group_by { |_, image_id| image_id }.each do |image_id, entries|
      warn "\n\e[36m=== Trivy scan: #{entries.map(&:first).join(', ')} ===\nImage ID: #{image_id}\e[0m"
      return 1 unless scan(image_id, trivy_args, tty)
    end
    verify_images(images)
    warn "\e[32mTrivy checks passed.#{trivy_args.empty? ? '' : " Options: #{trivy_args.shelljoin}"}\e[0m"
    0
  rescue StandardError => error
    warn error.message
    1
  end

  private

  def scan(image_id, trivy_args, tty)
    environment = ENV.keys.grep(/\ATRIVY_/) - %w[TRIVY_IMAGE]
    cache_dir = ENV.fetch('TRIVY_CACHE_DIR', '/root/.cache/trivy')
    system('docker', 'run', '--rm', '--pull', 'always', *(tty ? ['--tty'] : []),
           '--mount', 'type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock,readonly',
           '--mount', "type=volume,src=trivy-cache,dst=#{cache_dir}",
           *environment.flat_map { ['--env', _1] }, ENV.fetch('TRIVY_IMAGE', 'aquasec/trivy'),
           'image', '--cache-dir', cache_dir, '--image-src', 'docker', '--scanners', 'vuln',
           '--exit-code', '1', *trivy_args, image_id)
  end

  def empty_compose?(file)
    document = YAML.safe_load(File.read(file), aliases: true)
    document.is_a?(Hash) && document['services'] == {}
  rescue Psych::Exception
    false
  end

  def image_tags(targets, metadata)
    raise 'Invalid Bake target map' unless targets.is_a?(Hash)

    images = {}
    targets.each do |name, target|
      raise "Multiple platforms for target: #{name}" if (target['platforms'] || []).size > 1

      image_id = metadata.fetch(name).fetch('containerimage.config.digest')
      raise "Invalid image ID for target: #{name}" unless image_id.is_a?(String) && IMAGE_ID.match?(image_id)

      tags = target.fetch('tags')
      raise "Missing image tags for target: #{name}" unless tags.is_a?(Array) && !tags.empty?

      tags.each do |tag|
        raise "Invalid image tag for target: #{name}" unless tag.is_a?(String) && !tag.empty?
        raise "Conflicting image tag: #{tag}" if images.key?(tag) && images[tag] != image_id

        images[tag] = image_id
      end
    end
    images
  end

  def verify_images(images)
    actual = capture_json('docker', 'image', 'inspect', '--', *images.keys).map { _1.fetch('Id') }
    raise 'Image tags do not match build metadata' unless actual == images.values
  end

  def capture_json(*command)
    output, status = Open3.capture2(*command)
    raise "#{command.first} failed with status #{status.exitstatus}" unless status.success?

    JSON.parse(output)
  end
end
