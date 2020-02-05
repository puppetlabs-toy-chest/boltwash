#!/usr/bin/env ruby
# frozen_string_literal: true

require 'wash'

# For now we're going to mock out the plugin interface. It requires more setup
# to get PAL/PuppetDB working.
class Plugin
  attr_accessor :plugin_hooks
  def initialize
    @plugin_hooks = {}
  end

  def reference?(_input)
    false
  end

  def resolve_references(ref)
    ref
  end

  def resolve_top_level_references(ref)
    ref
  end
end

class Boltwash < Wash::Entry
  label 'bolt'
  is_singleton
  parent_of 'Group'
  description <<~DESC
    A plugin for Puppet Bolt's inventory. You can see target configuration in entry
    metadata. You can SSH to targets and view their filesystems in 'fs' directories.

    All groups are shown in this directory, with the special 'all' group including
    all targets in the inventory.
  DESC

  def init(config)
    require 'bolt/inventory'
    boltdir = config[:dir] ? Bolt::Boltdir.new(config[:dir]) : Bolt::Boltdir.default_boltdir
    bolt_config = Bolt::Config.from_boltdir(boltdir)
    @inventory = Bolt::Inventory.from_config(bolt_config, Plugin.new)
    prefetch :list
  end

  def list
    groups = @inventory.group_names
    groups.map { |group| Group.new(@inventory, group) }
  end
end

class Group < Wash::Entry
  label 'group'
  parent_of 'Target'
  description <<~DESC
    This is a group. Listing it shows all targets in the group.
  DESC

  def initialize(inventory, name)
    @inventory = inventory
    @name = name
    prefetch :list
  end

  def list
    targets = @inventory.get_targets(@name)
    targets.map { |target| Target.new(target) }
  end
end

def get_login_shell(target)
  # Bolt's inventory defines a shell as a feature. Some transports provide
  # default features as well. Use these to determine the login shell.
  if target.features.include?('powershell')
    'powershell'
  elsif target.features.include?('bash')
    'posixshell'
  elsif target.transport == 'winrm'
    'powershell'
  elsif target.transport == 'ssh' || target.transport.nil?
    'posixshell'
  end
end

class Target < Wash::Entry
  label 'target'
  parent_of VOLUMEFS
  state :target
  attributes :os
  description <<~DESC
    This is a target. You can view target configuration with the 'meta' command,
    and SSH to the target if it accepts SSH connections. If SSH works, the 'fs'
    directory will show its filesystem.
  DESC
  partial_metadata_schema begin
    # Provides a merge of v1 and v2 target schemas. This makes it possible to match
    # either while still providing useful information to Wash.
    {
      type: 'object',
      properties: {
        name: { type: 'string' },
        alias: {
          type: 'array'
        },
        uri: { type: 'string' },
        config: {
          type: 'object',
          properties: {
            transport: { type: 'string' },
            ssh: { type: 'object' },
            winrm: { type: 'object' },
            pcp: { type: 'object' },
            local: { type: 'object' },
            docker: { type: 'object' },
            remote: { type: 'object' }
          }
        },
        vars: {
          type: 'object'
        },
        features: {
          type: 'array'
        },
        facts: {
          type: 'object'
        },
        plugin_hooks: {
          type: 'object'
        }
      }
    }
  end

  def initialize(target)
    # Save just the target information we need as state.
    @name = target.name
    @partial_metadata = target.detail
    @target = target.to_h
    if (shell = get_login_shell(target))
      @os = { login_shell: shell }
    end
    prefetch :list
  end

  # Only implements SSH, WinRM, and Docker. Local is trivial, and remote is not
  # really usable. PCP I hope to implement later.
  def exec(cmd, args, opts)
    # lazy-load dependencies to make the plugin as fast as possible
    require 'bolt/target'
    require 'logging'

    # opts can contain 'tty', 'stdin', and 'elevate'. If tty is set, apply it
    # to the target for this exec.
    target_opts = @target.transform_keys(&:to_s)
    target_opts['tty'] = true if opts[:tty]
    target = Bolt::Target.new(@target[:uri], target_opts)

    logger = Logging.logger($stderr)
    logger.level = :warn

    transport = target.transport || 'ssh'
    case transport
    when 'ssh'
      require_relative 'transport_ssh.rb'
      connection = BoltSSH.new(target, logger)
    when 'winrm'
      require_relative 'transport_winrm.rb'
      connection = BoltWinRM.new(target, logger)
    when 'docker'
      require_relative 'transport_docker.rb'
      connection = BoltDocker.new(target)
    else
      raise "#{transport} unsupported"
    end

    begin
      connection.connect
      # Returns exit code
      connection.execute(cmd, args, stdin: opts[:stdin])
    ensure
      begin
        connection&.disconnect
      rescue StandardError => e
        logger.info("Failed to close connection to #{target}: #{e}")
      end
    end
  end

  def list
    [volumefs('fs', maxdepth: 2)]
  end
end

Wash.enable_entry_schemas
Wash.prefetch_entry_schemas
Wash.pretty_print
Wash.run(Boltwash, ARGV)
