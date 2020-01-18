#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bolt/inventory'
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
  description <<~DESC
    This is a target. You can view target configuration with the 'meta' command,
    and SSH to the target if it accepts SSH connections. If SSH works, the 'fs'
    directory will show its filesystem.
  DESC

  def known_hosts(host_key_check)
    return nil unless host_key_check == false

    # Disable host key checking by redirecting known hosts to an empty file
    # This is future-proofing for when Wash works on Windows.
    Gem.win_platform? ? 'NUL' : '/dev/null'
  end

  def transport_options(target)
    {
      host: target.host,
      port: target.port,
      user: target.user,
      password: target.password,
      identity_file: target.options['private-key'],
      known_hosts: known_hosts(target.options['host-key-check'])
    }
  end

  def initialize(target)
    # Save just the target information we need as state.
    @name = target.name
    @partial_metadata = target.detail
    # TODO: add WinRM
    transport :ssh, transport_options(target) if target.protocol == 'ssh'
    prefetch :list
  end

  def exec(*_args)
    raise 'non-ssh protocols are not yet implemented'
  end

  def list
    [volumefs('fs', maxdepth: 2)]
  end
end

Wash.enable_entry_schemas
Wash.prefetch_entry_schemas
Wash.pretty_print
Wash.run(Boltwash, ARGV)
