#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bolt/inventory'
require 'shellwords'
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


class Target < Wash::Entry
  label 'target'
  parent_of VOLUMEFS
  state :target
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
    prefetch :list
  end

  def exec(cmd, args, opts)
    raise 'input on stdin not supported' if opts[:stdin]

    # opts can contain 'tty', 'stdin', and 'elevate'. If tty is set, apply it
    # to the target for this exec.
    target_opts = @target.transform_keys {|k| k.to_s }
    target_opts['tty'] = true if opts[:tty]
    target = Bolt::Target.new(@target[:uri], target_opts)
    raise 'remote transport not supported' if target.transport == 'remote'

    transport = target.transport || 'ssh'
    transport_class = Bolt::TRANSPORTS[transport.to_sym]
    raise "unknown transport #{transport}" if transport_class.nil?

    transport = transport_class.new
    result = transport.run_command(target, Shellwords.join([cmd] + args))

    $stdout.write(result['stdout'])
    $stderr.write(result['stderr'])
    result['exit_code']
  end

  def list
    [volumefs('fs', maxdepth: 2)]
  end
end

Wash.enable_entry_schemas
Wash.prefetch_entry_schemas
Wash.pretty_print
Wash.run(Boltwash, ARGV)
