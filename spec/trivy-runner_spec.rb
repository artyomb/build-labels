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
        puts fixture.fetch('scan_output', "Scanning #{ARGV.last}")
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
    expect(output).not_to include('Trivy checks passed.', '=== Trivy scan:')
    expect(errors).to eq("\n\e[36m=== Trivy scan: #{tags.join(', ')} ===\nImage ID: #{image_id}\e[0m\n" \
                        "\e[32mTrivy checks passed.\e[0m\n")
    expect(calls.first).to eq(['docker', 'buildx', 'bake', '-f', @file, '--print', '--'])
    expect(scans).to eq([['docker', 'run', '--rm', '--pull', 'always', '--tty',
                         '--mount', 'type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock,readonly',
                         '--mount', 'type=volume,src=trivy-cache,dst=/root/.cache/trivy',
                         'aquasec/trivy', 'image', '--cache-dir', '/root/.cache/trivy',
                         '--image-src', 'docker', '--scanners', 'vuln',
                         '--exit-code', '1', image_id]])
    expect(calls.count { _1.take(3) == ['docker', 'image', 'inspect'] }).to eq(2)
    expect(calls.last).to eq(['docker', 'image', 'inspect', '--', *tags])
  end

  it 'allows overriding the scanner image without forwarding the wrapper setting' do
    scanner_image = "registry.example/trivy@sha256:#{'c' * 64}"
    expect(invoke(env: {'TRIVY_IMAGE' => scanner_image}).last.exitstatus).to eq(0)
    expect(scans.first).to include(scanner_image)
    expect(scans.first).not_to include('TRIVY_IMAGE', 'aquasec/trivy')
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

  it 'scans all distinct images with explicit terminal output and reports success once' do
    plan['target']['other'] = {'tags' => ['other:1.0']}
    metadata['other'] = {'containerimage.config.digest' => other_id}
    fixture['images']['other:1.0'] = other_id
    _, errors, status = invoke('--tty')
    expect(status.exitstatus).to eq(0), errors
    expect(scans.map(&:last)).to eq([image_id, other_id])
    expect(errors.scan('=== Trivy scan:').size).to eq(2)
    expect(errors.index("Image ID: #{image_id}")).to be < errors.index("Image ID: #{other_id}")
    expect(errors).to include('=== Trivy scan: other:1.0 ===')
    expect(errors.scan('Trivy checks passed.').size).to eq(1)
    expect(errors).to end_with("\e[32mTrivy checks passed.\e[0m\n")
    scans.each do |scan|
      expect(scan.take_while { _1 != 'aquasec/trivy' }).to include('--tty')
      expect(scan).not_to include('-i', '--interactive')
    end
    expect(calls.first).not_to include('--tty')
  end

  it 'uses the native severity option without injecting another severity filter' do
    _, errors, status = invoke('--', '--severity', 'CRITICAL')
    expect(status.exitstatus).to eq(0)
    expect(errors).to end_with("\e[32mTrivy checks passed. Options: --severity CRITICAL\e[0m\n")
    expect(scans.first.last(3)).to eq(['--severity', 'CRITICAL', image_id])
    expect(scans.first.count('--severity')).to eq(1)
    expect(scans.first).not_to include('HIGH,CRITICAL')
  end

  it 'passes target and group arguments without shell interpretation' do
    target = "app; touch #{File.join(@directory, 'unwanted')}"
    expect(invoke(target).last.exitstatus).to eq(0)
    expect(calls.first.last(2)).to eq(['--', target])
    expect(File.exist?(File.join(@directory, 'unwanted'))).to be(false)
  end

  it 'forwards native Trivy options and values after the separator without changing Bake targets' do
    trivy_args = ['--severity', 'HIGH,CRITICAL', '--ignore-unfixed', '--no-progress', '--timeout', '10m', '-f', 'json']
    fixture['scan_output'] = '[]'
    output, errors, status = invoke('--no-tty', 'app', 'release', '--', *trivy_args)
    expect(status.exitstatus).to eq(0)
    expect(output).to eq("[]\n")
    expect(errors).to end_with("\e[32mTrivy checks passed. Options: --severity HIGH,CRITICAL --ignore-unfixed " \
                              "--no-progress --timeout 10m -f json\e[0m\n")
    expect(scans.first).not_to include('--tty', '--no-tty')
    expect(calls.first.last(3)).to eq(['--', 'app', 'release'])
    expect(scans.first.last(trivy_args.size + 1)).to eq([*trivy_args, image_id])
  end

  it 'passes Trivy argument values without shell interpretation' do
    template = "{{ range . }}{{ .Target }}{{ end }}; touch #{File.join(@directory, 'unwanted')}"
    expect(invoke('--', '--format=template', '--template', template).last.exitstatus).to eq(0)
    expect(scans.first.last(4)).to eq(['--format=template', '--template', template, image_id])
    expect(File.exist?(File.join(@directory, 'unwanted'))).to be(false)
  end

  it 'disables terminal output and forwards Trivy options to every distinct image' do
    plan['target']['other'] = {'tags' => ['other:1.0']}
    metadata['other'] = {'containerimage.config.digest' => other_id}
    fixture['images']['other:1.0'] = other_id
    expect(invoke('--no-tty', '--', '--ignore-unfixed').last.exitstatus).to eq(0)
    expect(scans.map { _1.last(2) }).to eq([['--ignore-unfixed', image_id], ['--ignore-unfixed', other_id]])
    scans.each { expect(_1).not_to include('--tty', '--no-tty') }
    expect(calls.first).not_to include('--no-tty')
  end

  it 'rejects native Trivy options before the separator' do
    expect(invoke('--ignore-unfixed').last.exitstatus).to eq(1)
    expect(calls).to be_empty
  end

  it 'accepts an empty list of forwarded options' do
    expect(invoke('--').last.exitstatus).to eq(0)
    expect(calls.first.last).to eq('--')
    expect(scans.first.last(3)).to eq(['--exit-code', '1', image_id])
  end

  it 'ignores metadata belonging to unselected targets' do
    metadata['unselected'] = {'containerimage.config.digest' => other_id}
    expect(invoke('app').last.exitstatus).to eq(0)
    expect(scans.map(&:last)).to eq([image_id])
  end

  it 'rejects the removed fail-on wrapper option' do
    expect(invoke('--fail-on=HIGH,CRITICAL').last.exitstatus).to eq(1)
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
    expect(output).to include('Usage: trivy-runner', '--[no-]tty', 'default: enabled')
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
    _, errors, status = invoke
    expect(status.exitstatus).to eq(0)
    expect(errors).to be_empty
    expect(calls).to be_empty
  end

  it 'skips an empty resolved Bake target map' do
    plan['target'] = {}
    _, errors, status = invoke
    expect(status.exitstatus).to eq(0)
    expect(errors).to be_empty
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
    _, errors, status = invoke
    expect(status.exitstatus).to eq(1)
    expect(errors).not_to include('Trivy checks passed.')
    expect(scans.length).to eq(1)
  end

  it 'stops at the first failed scan' do
    plan['target']['other'] = {'tags' => ['other:1.0']}
    metadata['other'] = {'containerimage.config.digest' => other_id}
    fixture['images']['other:1.0'] = other_id
    fixture['scan_status'] = 1
    _, errors, status = invoke('--tty', '--', '--ignore-unfixed')
    expect(status.exitstatus).to eq(1)
    expect(errors).not_to include('Trivy checks passed.')
    expect(errors.scan('=== Trivy scan:').size).to eq(1)
    expect(errors).not_to include("Image ID: #{other_id}")
    expect(scans.map(&:last)).to eq([image_id])
    expect(calls.last).to eq(scans.last)
  end

  it 'fails on scanner operational errors' do
    fixture['scan_status'] = 2
    _, errors, status = invoke
    expect(status.exitstatus).to eq(1)
    expect(errors).not_to include('Trivy checks passed.')
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
