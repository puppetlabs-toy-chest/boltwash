#!/usr/bin/env ruby

require 'wash'
require 'json'
require 'bolt/inventory'
# TODO: should be required by bolt/config, where it's used.
require 'bolt/logger'

class Boltwash < Wash::Entry
  label 'bolt'
  is_singleton
  parent_of 'Group'

  def init(config)
    boltdir = config['dir']
    boltdir ||= Bolt::Boltdir.default_boltdir

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
    # TODO: expose a way to get group names
    group = @inventory.instance_variable_get(:@group_lookup)[@name]
    group.nodes.keys.map { |target| Target.new(@inventory, target)}
  end
end

class Target < Wash::Entry
  label 'target'

  def initialize(inventory, name)
    # TODO: get target details from inventory and save as state
    @name = name
  end
end

Wash.enable_entry_schemas
Wash.prefetch_entry_schemas
Wash.pretty_print
Wash.run(Boltwash, ARGV)
