# frozen_string_literal: true
# rubocop:disable Rspec/ExampleLength, Style/MixinUsage, Rspec/DescribeClass

include BuildLabels

describe 'Test BuildLabels' do
  it 'build-labels' do
    # ENV.delete_if { _1 =~/BUNDLE|DEBUG|IDE_PROCESS_DISPATCHER/ }

    # Dir[File.expand_path('data/*.drs', __dir__)].each do |stack_file|
      response = `bundle exec ./bin/build-labels -c ./examples/simple-compose.yml gitlab cache to_dockerfiles to_compose`
      puts response
      expect(1).to eq(1)
    #end
  end
end

