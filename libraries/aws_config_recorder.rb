# frozen_string_literal: true

require 'aws_backend'

class AwsConfigurationRecorder < AwsResourceBase
  name 'aws_config_recorder'
  desc 'Verifies settings for AWS Configuration Recorder'
  example "
    describe aws_config_recorder('My_Recorder') do
      it { should exist }
      it { should be_recording }
      it { should be_all_supported }
      it { should have_include_global_resource_types }
    end
  "
  attr_reader :role_arn, :resource_types, :recorder_name, :recording_all_resource_types, :recording_all_global_types
  alias recording_all_resource_types? recording_all_resource_types
  alias recording_all_global_types? recording_all_global_types

  def initialize(opts = {})
    opts = { recorder_name: opts } if opts.is_a?(String)

    super(opts)
    validate_parameters([:recorder_name]) unless opts.nil?

    query = !opts.nil? && opts.key?(:recorder_name) ? { configuration_recorder_names: opts[:recorder_name] } : {}

    catch_aws_errors do
      begin
        resp = @aws.config_client.describe_configuration_recorders(query)
        raise ArgumentError, 'Error: unexpectedly received multiple AWS Config Recorder objects from API; expected to be singleton per-region. ' if @resp.configuration_recorders.count > 1
      rescue Aws::ConfigService::Errors::NoSuchConfigurationRecorderException
        return
      end
      recorder        = resp.configuration_recorders.first.to_h
      @role_arn       = recorder[:role_arn]
      @recorder_name  = recorder[:name]
      @resource_types = recorder[:recording_group][:resource_types]
      @recording_all_resource_types = recorder[:recording_group][:all_supported]
      @recording_all_global_types   = recorder[:recording_group][:include_global_resource_types]
    end
  end

  def exists?
    !@role_arn.nil?
  end

  def status
    return {} unless exists?
    catch_aws_errors do
      @status_response = @aws.config_client.describe_configuration_recorder_status(configuration_recorder_names: [@recorder_name])
      @status = @status_response.configuration_recorders_status.first.to_h
    end
  end

  def recording?
    return false unless exists?
    status[:recording]
  end

  def to_s
    opts.key?(:aws_region) ? "Configuration Recorder #{@recorder_name} in #{opts[:aws_region]}" : "Configuration Recorder #{@recorder_name}"
  end
end
