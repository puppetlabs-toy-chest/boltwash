#!/usr/bin/env ruby

require 'wash'
require 'json'
require 'bolt/inventory'
# TODO: should be required by bolt/config, where it's used.
require 'bolt/logger'

def setup_inventory(inventory)
  if inventory[:config]
    inventory = JSON.parse(inventory.to_json)
  end

  config = Bolt::Config.default
  config.overwrite_transport_data(inventory['config']['transport'],
                                  Bolt::Util.symbolize_top_level_keys(inventory['config']['transports']))

  Bolt::Inventory.new(inventory['data'],
                      config,
                      Bolt::Util.symbolize_top_level_keys(inventory['target_hash']))
end

class Boltwash < Wash::Entry
  label 'bolt'
  is_singleton
  parent_of 'Group'
  state :inventory_data

  def init(config)
    boltdir = config['dir']
    boltdir ||= Bolt::Boltdir.default_boltdir

    bolt_config = Bolt::Config.from_boltdir(boltdir)
    @inventory_data = Bolt::Inventory.from_config(bolt_config).data_hash
  end

  def list
    groups = setup_inventory(@inventory_data).group_names
    groups.map { |group| Group.new(@inventory_data, group) }
  end
end

class Group < Wash::Entry
  label 'group'
  parent_of 'Target'
  state :inventory_data

  def initialize(data, name)
    @inventory_data = data
    @name = name
  end

  def list
    group = setup_inventory(@inventory_data).instance_variable_get(:@group_lookup)[@name]
    group.nodes.keys.map { |target| Target.new(@inventory_data, target)}
  end
end

class Target < Wash::Entry
  label 'target'
  state :inventory_data

  def initialize(data, name)
    @inventory_data = data
    @name = name
  end
end

Wash.enable_entry_schemas
Wash.prefetch_entry_schemas
Wash.pretty_print
Wash.run(Boltwash, ARGV)
