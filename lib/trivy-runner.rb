require 'json'
require 'open3'
require 'optparse'
require 'yaml'
require_relative 'version'

class TrivyRunner
  SEVERITIES = %w[UNKNOWN LOW MEDIUM HIGH CRITICAL].freeze
  IMAGE_ID = /\Asha256:[0-9a-f]{64}\z/

  def run(args)
    file = 'bake.yml'
    metadata_file = nil
    severity = %w[HIGH CRITICAL]
    parser = OptionParser.new do |options|
      options.banner = 'Usage: trivy-runner -f BAKE_FILE --metadata-file FILE [TARGET/GROUP ...]'
      options.on('-f', '--file FILE', 'Bake or Compose file (default: bake.yml)') { file = _1 }
      options.on('--metadata-file FILE', 'Buildx metadata from the local build') { metadata_file = _1 }
      options.on('--image-src SOURCE', %w[docker], 'Image source (default: docker)')
      options.on('--fail-on SEVERITIES', Array, 'Fail on these severities (default: HIGH,CRITICAL)') do |values|
        severity = values.map { _1.strip.upcase }.uniq
        if severity.empty? || (severity - SEVERITIES).any?
          raise OptionParser::InvalidArgument, values.join(',')
        end
      end
      options.on('-v', '--version', 'Print version') { puts BuildLabels::Builder::VERSION; return 0 }
      options.on('-h', '--help', 'Print help') { puts options; return 0 }
    end
    targets = parser.parse!(args.dup)
    raise OptionParser::MissingArgument, '--metadata-file' unless metadata_file
    return 0 if targets.empty? && empty_compose?(file)

    metadata = JSON.parse(File.read(metadata_file))
    plan = capture_json('docker', 'buildx', 'bake', '-f', file, '--print', '--', *targets)
    images = image_tags(plan.fetch('target'), metadata)
    return 0 if images.empty?

    verify_images(images)
    images.values.uniq.each do |image_id|
      return 1 unless system('trivy', 'image', '--image-src', 'docker', '--scanners', 'vuln',
                             '--severity', severity.join(','), '--exit-code', '1', image_id)
    end
    verify_images(images)
    0
  rescue StandardError => error
    warn error.message
    1
  end

  private

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
