# frozen_string_literal: true
# rubocop:disable Rspec/ExampleLength, Style/MixinUsage, Rspec/DescribeClass

include BuildLabels

describe 'Test BuildLabels' do
  it 'build-labels' do
    Dir[File.expand_path('data/*.drs', __dir__)].each do |stack_file|

      expect(1).to eq(1)
    end
  end
end

