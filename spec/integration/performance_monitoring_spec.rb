require 'spec_helper'
require 'tempfile'
require 'thread'

RSpec.describe 'Cloud controller', type: :integration, monitoring: true do
  let(:port) { 8181 }

  let(:newrelic_config_file) {
    File.expand_path(File.join(File.dirname(__FILE__), '../fixtures/config/newrelic.yml'))
  }

  let(:base_cc_config_file) {
    'config/cloud_controller.yml'
  }

  let(:port_8181_overrides) {
    'spec/fixtures/config/port_8181_config.yml'
  }

  before :each do
    FileUtils.rm_f('/tmp/newrelic/development.log')
    opts = {
      debug: false,
      config: cc_config_file.path,
      env: {
        'NRCONFIG' => newrelic_config_file,
        'NEW_RELIC_ENV' => 'development'
      }
    }
    start_cc(opts)
  end

  let(:cc_config_file) do
    config = YAML.load_file(base_cc_config_file).deep_merge(YAML.load_file(port_8181_overrides)).merge(cc_config)
    file = Tempfile.new('cc_config.yml')
    file.write(YAML.dump(config))
    file.close
    file
  end

  after :each do
    stop_cc
    cc_config_file.unlink
    FileUtils.rm_f('/tmp/newrelic/development.log')
  end

  context 'when new_relic is enabled' do
    context 'when developer_mode is enabled' do
      let(:cc_config) do
        { 'development_mode' => true, 'newrelic_enabled' => true }
      end

      it 'reports the transaction information in /newrelic' do
        info_response = make_get_request('/info', {}, port)
        expect(info_response.code).to eq('200')

        newrelic_response = make_get_request('/newrelic', {}, port)
        expect(newrelic_response.code).to eq('200')
        expect(newrelic_response.body).to include('/info')
      end
    end

    context 'when developer_mode is not enabled' do
      let(:cc_config) do
        { 'development_mode' => false, 'newrelic_enabled' => true }
      end

      it 'does not report transaction information in /newrelic' do
        newrelic_response = make_get_request('/newrelic', {}, port)
        expect(newrelic_response.code).to eq('404')
      end

      it 'loads new relic' do
        expect(File).to exist('/tmp/newrelic/development.log')
      end
    end
  end

  context 'when new relic is disabled' do
    context 'even when developer mode is enabled' do
      let(:cc_config) do
        { 'development_mode' => true, 'newrelic_enabled' => false }
      end

      it 'does not report transaction information in /newrelic' do
        newrelic_response = make_get_request('/newrelic', {}, port)
        expect(newrelic_response.code).to eq('404')
      end

      it 'does not load new relic' do
        expect(File).not_to exist('/tmp/newrelic/development.log')
      end
    end
  end
end
