#
# Copyright 2013-2014, SUSE LINUX Products GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class UpdaterService < ServiceObject
  def initialize(thelogger)
    super(thelogger)
    @bc_name = "updater"
  end

  class << self
    def role_constraints
      {
        "updater" => {
          "unique" => false,
          "count" => -1,
          "admin" => true,
          "exclude_platform" => {
            "windows" => "/.*/"
          }
        },
        "updater-upgrade" => {
          "unique" => false,
          "count" => -1,
          "admin" => false,
          "exclude_platform" => {
            "windows" => "/.*/"
          }
        }
      }
    end
  end

  def create_proposal
    @logger.debug("Updater create_proposal: entering")
    base = super
    @logger.debug("Updater create_proposal: leaving base part")

    nodes = NodeObject.all
    # Don't include the admin node by default, you never know...
    nodes.delete_if { |n| n.nil? or n.admin? }

    # Ignore nodes that are being discovered
    base["deployment"]["updater"]["elements"] = {
      "updater" => nodes.select { |x| not ["discovering", "discovered"].include?(x.status) }.map { |x| x.name }
    }

    @logger.debug("updater create_proposal: exiting")
    base
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Updater apply_role_post_chef_call: entering #{all_nodes.inspect}")
    # Remove [:updater][...] flags from node
    all_nodes.each do |n|
      node = NodeObject.find_node_by_name n
      unless node[:updater].nil?
        if node.role? "updater"
          node[:updater][:one_shot_run] = false
          @logger.debug("Updater apply_role_post_chef_call: delete [:updater][:one_shot_run] for #{node.name} (#{node[:updater].inspect}")
          node.save
        end
        if node.role? "updater-upgrade"
        node[:updater][:upgrade_one_shot_run] = false
        @logger.debug("Updater apply_role_post_chef_call: delete [:updater][:upgrade_one_shot_run] for #{node.name} (#{node[:updater].inspect}")
        node.save
        end
      end
    end
    all_nodes.each do |n|
      node = NodeObject.find_node_by_name n
      if node.role? "updater-upgrade"
        role_name = NodeObject.make_role_name(node.name)
        storage_role = RoleObject.find_role_by_name(role_name)
        storage_role = role
        # TODO: Make sure that storage_role.name does not already exist
        storage_role.name= role.name+"-upgrade_storage"
        storage_role.save
        node.delete_from_run_list(role.name)
        # TODO: Find out if there can be more than one role on the run_list -
        # If so, handle that in a proper way
        node.add_to_run_list("updater-upgrade", 2000)
        node.save
      end
    end

   ## Rather work directly on Chef::Node objects to avoid Crowbar's deep_merge stuff
   #ChefObject.query_chef.search("node")[0].each do |node|
   #  if node.has_key?(:updater) && node[:updater].has_key?(:one_shot_run)
   #    node[:updater][:one_shot_run] = false
   #    @logger.debug("Updater apply_role_post_chef_call: delete [:updater][:one_shot_run] for #{node.name} (#{node[:updater].inspect}")
   #    node.save
   #  end
   #end
    @logger.debug("Updater apply_role_post_chef_call: exiting")
  end

  def apply_role_post_chef_call(old_role, role, all_nodes)
    all_nodes.each do |n|
      node = NodeObject.find_node_by_name n
      if node.role? "updater-upgrade"
        # Put together storage role name
        role_name = NodeObject.make_role_name(node.name)
        role  = RoleObject.find_role_by_name(role_name+"-upgrade_storage")
        role.name = role_name
        node.delete_from_run_list("updater-upgrade")
#        priority = runlist_priority_map[item] || local_chef_order
        priority = 1
        # FIXME: Not sure if this works, and if it does, find solution for priority
        node.add_to_run_list(role.name, priority)
        node.crowbar["state"] = "upgrade"
        # Cleanup storage role
        RoleObject.destroy(role_name+"-upgrade_storage")
        node.save
      end
    end
    role_name = role.name
    Rails.logger.info " updater_service: role_name: #{role_name}"
  end


  def oneshot?
    true
  end
end
