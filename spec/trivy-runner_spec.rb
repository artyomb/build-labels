require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'
require_relative '../lib/trivy-runner'

RSpec.describe TrivyRunner do
  let(:image_id) { "sha256:#{'a' * 64}" }
  let(:other_id) { "sha256:#{'b' * 64}" }
  let(:tags) { ['registry.example:5000/app:1.0', 'registry.example:5000/app:latest'] }
  let(:plan) { {'target' => {'app' => {'tags' => tags, 'platforms' => ['linux/amd64']}}} }
  let(:metadata) { {'app' => {'containerimage.config.digest' => image_id}} }
  let(:metadata_json) { JSON.generate(metadata) }
  let(:fixture) { {'plan' => plan, 'images' => tags.to_h { [_1, image_id] }} }

  around do |example|
    Dir.mktmpdir('trivy-runner-') do |directory|
      @directory = directory
      @file = File.join(directory, 'bake file.yml')
      @metadata = File.join(directory, 'metadata.json')
      @log = File.join(directory, 'commands.jsonl')
      File.write(@file, "services:\n  app:\n    image: app\n    build: .\n")
      path = File.join(directory, 'docker')
      File.write(path, "#!#{RbConfig.ruby}\n" + fake_tool)
      File.chmod(0o755, path)
      example.run
    end
  end

  def fake_tool
    <<~'RUBY'
      require 'json'
      fixture = JSON.parse(File.read(ENV.fetch('SCAN_FIXTURE')))
      tool = File.basename($0)
      File.open(ENV.fetch('SCAN_LOG'), 'a') { _1.puts JSON.generate([tool, *ARGV]) }
      case ARGV.take(2)
      when ['run', '--rm']
        puts "Scanning #{ARGV.last}"
        exit fixture.fetch('scan_status', 0)
      when ['buildx', 'bake']
        abort 'Unexpected build operation' unless ARGV.include?('--print')
        abort 'Bake failed' if fixture['bake_failure']
        puts JSON.generate(fixture.fetch('plan'))
      when ['image', 'inspect']
        abort 'Image lookup failed' if fixture['inspect_failure']
        calls = File.readlines(ENV.fetch('SCAN_LOG')).map { JSON.parse(_1) }
        second_inspect = calls.count { _1.take(3) == ['docker', 'image', 'inspect'] } > 1
        images = second_inspect ? fixture.fetch('images_after', fixture.fetch('images')) : fixture.fetch('images')
        puts JSON.generate(ARGV.drop(3).map { {'Id' => images.fetch(_1)} })
      else
        abort "Unexpected Docker operation: #{ARGV.inspect}"
      end
    RUBY
  end

  def invoke(*args, include_metadata: true, env: {})
    fixture_path = File.join(@directory, 'fixture.json')
    File.write(fixture_path, JSON.generate(fixture))
    File.write(@metadata, metadata_json)
    options = ['-f', @file]
    options += ['--metadata-file', @metadata] if include_metadata
    environment = {'PATH' => @directory, 'SCAN_FIXTURE' => fixture_path, 'SCAN_LOG' => @log}.merge(env)
    Open3.capture3(environment, RbConfig.ruby, File.expand_path('../bin/trivy-runner', __dir__),
                   *options, *args, unsetenv_others: true)
  end

  def calls
    File.exist?(@log) ? File.readlines(@log).map { JSON.parse(_1) } : []
  end

  def scans = calls.select { _1.take(2) == ['docker', 'run'] }

  it 'scans the built image once for multiple tags and verifies tags before and after' do
    output, errors, status = invoke('--image-src', 'docker')
    expect(status.exitstatus).to eq(0), errors
    expect(output).to include(image_id)
    expect(calls.first).to eq(['docker', 'buildx', 'bake', '-f', @file, '--print', '--'])
    expect(scans).to eq([['docker', 'run', '--rm',
                         '--mount', 'type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock,readonly',
                         '--mount', 'type=volume,src=trivy-cache,dst=/root/.cache/trivy',
                         'aquasec/trivy:0.74.0', 'image', '--cache-dir', '/root/.cache/trivy',
                         '--image-src', 'docker', '--scanners', 'vuln',
                         '--severity', 'HIGH,CRITICAL', '--exit-code', '1', image_id]])
    expect(calls.count { _1.take(3) == ['docker', 'image', 'inspect'] }).to eq(2)
    expect(calls.last).to eq(['docker', 'image', 'inspect', '--', *tags])
  end

  it 'allows overriding the scanner image without forwarding the wrapper setting' do
    scanner_image = "registry.example/trivy@sha256:#{'c' * 64}"
    expect(invoke(env: {'TRIVY_IMAGE' => scanner_image}).last.exitstatus).to eq(0)
    expect(scans.first).to include(scanner_image)
    expect(scans.first).not_to include('TRIVY_IMAGE', 'aquasec/trivy:0.74.0')
  end

  it 'forwards Trivy environment variable names without exposing values in arguments' do
    env = {'TRIVY_IGNORE_UNFIXED' => 'true', 'TRIVY_TOKEN' => 'test-token', 'UNRELATED' => 'value'}
    expect(invoke(env: env).last.exitstatus).to eq(0)
    expect(scans.first.each_cons(2).to_a).to include(['--env', 'TRIVY_IGNORE_UNFIXED'], ['--env', 'TRIVY_TOKEN'])
    expect(scans.first).not_to include('test-token', 'UNRELATED')
  end

  it 'mounts the persistent cache at the configured container path' do
    expect(invoke(env: {'TRIVY_CACHE_DIR' => '/scan cache'}).last.exitstatus).to eq(0)
    expect(scans.first).to include('type=volume,src=trivy-cache,dst=/scan cache')
    expect(scans.first.each_cons(2).to_a).to include(['--cache-dir', '/scan cache'])
  end

  it 'deduplicates images shared by different targets' do
    plan['target']['alias'] = {'tags' => ['registry.example:5000/app:alias']}
    metadata['alias'] = {'containerimage.config.digest' => image_id}
    fixture['images']['registry.example:5000/app:alias'] = image_id
    expect(invoke.last.exitstatus).to eq(0)
    expect(scans.length).to eq(1)
  end

  it 'scans all distinct images' do
    plan['target']['other'] = {'tags' => ['other:1.0']}
    metadata['other'] = {'containerimage.config.digest' => other_id}
    fixture['images']['other:1.0'] = other_id
    expect(invoke.last.exitstatus).to eq(0)
    expect(scans.map(&:last)).to eq([image_id, other_id])
  end

  it 'normalizes configured severities' do
    expect(invoke('--fail-on=critical,high,critical').last.exitstatus).to eq(0)
    expect(scans.first).to include('CRITICAL,HIGH')
  end

  it 'passes target and group arguments without shell interpretation' do
    target = 'app; touch unwanted'
    expect(invoke('--', target).last.exitstatus).to eq(0)
    expect(calls.first.last(2)).to eq(['--', target])
    expect(File.exist?(File.join(@directory, 'unwanted'))).to be(false)
  end

  it 'ignores metadata belonging to unselected targets' do
    metadata['unselected'] = {'containerimage.config.digest' => other_id}
    expect(invoke('app').last.exitstatus).to eq(0)
    expect(scans.map(&:last)).to eq([image_id])
  end

  it 'rejects unknown severity names before running tools' do
    expect(invoke('--fail-on=critical,major').last.exitstatus).to eq(1)
    expect(calls).to be_empty
  end

  it 'rejects an empty severity list' do
    expect(invoke('--fail-on=').last.exitstatus).to eq(1)
    expect(calls).to be_empty
  end

  it 'rejects registry fallback for local build metadata' do
    expect(invoke('--image-src=remote').last.exitstatus).to eq(1)
    expect(calls).to be_empty
  end

  it 'requires build metadata' do
    expect(invoke(include_metadata: false).last.exitstatus).to eq(1)
    expect(calls).to be_empty
  end

  it 'prints help without requiring metadata or external tools' do
    output, _, status = invoke('--help', include_metadata: false)
    expect(status.exitstatus).to eq(0)
    expect(output).to include('Usage: trivy-runner')
    expect(calls).to be_empty
  end

  it 'prints the gem version without running external tools' do
    output, _, status = invoke('--version', include_metadata: false)
    expect(status.exitstatus).to eq(0)
    expect(output.strip).to eq(BuildLabels::Builder::VERSION)
    expect(calls).to be_empty
  end

  it 'skips an empty Compose service list' do
    File.write(@file, "services: {}\n")
    expect(invoke.last.exitstatus).to eq(0)
    expect(calls).to be_empty
  end

  it 'skips an empty resolved Bake target map' do
    plan['target'] = {}
    expect(invoke.last.exitstatus).to eq(0)
    expect(scans).to be_empty
  end

  it 'rejects malformed Bake target maps' do
    plan['target'] = []
    expect(invoke.last.exitstatus).to eq(1)
    expect(scans).to be_empty
  end

  it 'rejects targets missing build metadata' do
    metadata.clear
    expect(invoke.last.exitstatus).to eq(1)
    expect(scans).to be_empty
  end

  it 'rejects invalid image IDs' do
    metadata['app']['containerimage.config.digest'] = 'latest'
    expect(invoke.last.exitstatus).to eq(1)
    expect(scans).to be_empty
  end

  it 'rejects targets without image tags' do
    plan['target']['app']['tags'] = []
    expect(invoke.last.exitstatus).to eq(1)
    expect(scans).to be_empty
  end

  it 'rejects multi-platform targets' do
    plan['target']['app']['platforms'] = %w[linux/amd64 linux/arm64]
    expect(invoke.last.exitstatus).to eq(1)
    expect(scans).to be_empty
  end

  it 'rejects conflicting tags across targets' do
    plan['target']['other'] = {'tags' => [tags.first]}
    metadata['other'] = {'containerimage.config.digest' => other_id}
    expect(invoke.last.exitstatus).to eq(1)
    expect(scans).to be_empty
  end

  it 'rejects stale local tags before scanning' do
    fixture['images'][tags.last] = other_id
    expect(invoke.last.exitstatus).to eq(1)
    expect(scans).to be_empty
  end

  it 'fails if tags change during scanning' do
    fixture['images_after'] = fixture['images'].merge(tags.last => other_id)
    expect(invoke.last.exitstatus).to eq(1)
    expect(scans.length).to eq(1)
  end

  it 'stops at the first failed scan' do
    plan['target']['other'] = {'tags' => ['other:1.0']}
    metadata['other'] = {'containerimage.config.digest' => other_id}
    fixture['images']['other:1.0'] = other_id
    fixture['scan_status'] = 1
    expect(invoke.last.exitstatus).to eq(1)
    expect(scans.map(&:last)).to eq([image_id])
    expect(calls.last).to eq(scans.last)
  end

  it 'fails on scanner operational errors' do
    fixture['scan_status'] = 2
    expect(invoke.last.exitstatus).to eq(1)
  end

  [125, 126, 127].each do |exit_code|
    it "fails when the scanner container cannot run (status #{exit_code})" do
      fixture['scan_status'] = exit_code
      expect(invoke.last.exitstatus).to eq(1)
      expect(calls.last).to eq(scans.last)
    end
  end

  it 'fails when Docker is unavailable' do
    File.rename(File.join(@directory, 'docker'), File.join(@directory, 'docker.disabled'))
    expect(invoke.last.exitstatus).to eq(1)
    expect(calls).to be_empty
  end

  it 'fails when resolving the Bake plan fails' do
    fixture['bake_failure'] = true
    expect(invoke.last.exitstatus).to eq(1)
    expect(scans).to be_empty
  end

  it 'fails when Docker cannot inspect an image' do
    fixture['inspect_failure'] = true
    expect(invoke.last.exitstatus).to eq(1)
    expect(scans).to be_empty
  end

  context 'with malformed metadata JSON' do
    let(:metadata_json) { '{' }

    it 'fails before invoking tools' do
      expect(invoke.last.exitstatus).to eq(1)
      expect(calls).to be_empty
    end
  end
end
