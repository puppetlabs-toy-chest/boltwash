#!/usr/bin/env ruby

require 'bolt/inventory'
# Remove after next Bolt release.
require 'bolt/logger'
require 'wash'

class Boltwash < Wash::Entry
  label 'bolt'
  is_singleton
  parent_of 'Group'

  def init(config)
    boltdir = config['dir'] || Bolt::Boltdir.default_boltdir
    bolt_config = Bolt::Config.from_boltdir(boltdir)
    @inventory = Bolt::Inventory.from_config(bolt_config)
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
  state :connection_info

  def initialize(target)
    # Save just the target information we need as state.
    @name = target.name
    @partial_metadata = target.detail
    @connection_info = target.to_h
  end
end

Wash.enable_entry_schemas
Wash.prefetch_entry_schemas
Wash.pretty_print
Wash.run(Boltwash, ARGV)
