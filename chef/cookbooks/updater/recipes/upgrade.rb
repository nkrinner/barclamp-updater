#
# Cookbook Name:: updater
# Recipe:: upgrade
#
# Copyright 2013-2015, SUSE LINUX Products GmbH
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


# Disable openstack services
# We don't know which openstack services are enabled on the node and
# collecting that information via the attributes provided by chef is
# is rather complicated. So instead we fall back to a simple bash hack

if !node[:updater].has_key?(:upgrade_one_shot_run) || !node[:updater][:upgrade_one_shot_run]

  node[:updater][:upgrade_one_shot_run] = true
  node.save


  bash "disable_openstack_services" do
    code <<-EOF
      for i in /etc/init.d/openstack-* /etc/init.d/openvswitch-switch /etc/init.d/ovs-usurp-config-* /etc/init.d/drbd /etc/init.d/openais;
      do
        if test -e $i
        then
          initscript=`basename $i`
          insserv -r $initscript
        fi
      done
    EOF
    only_if { node[:platform] == "suse" }
  end

  # Disable crowbar-join
  service "crowbar_join" do
    action :disable
    only_if { node[:platform] == "suse" }
  end

  # Disable chef-client
  service "chef-client" do
    action [:disable, :stop]
    only_if { node[:platform] == "suse" }
  end
end
