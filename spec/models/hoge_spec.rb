require 'spec_helper'

describe Model do
  before{
    Fixture.load
    NodeNotification.clear
    Model.constants.each do |name|
      klass = Model.const_get name
      klass.class_eval{
        after_save :notify_create, on: :create
        after_save :notify_update, on: :update
        after_destroy :notify_destroy
      }
    end
  }
  it 'fixtures loaded' do
    expected = {
      Model::Root => 1,
      Model::BranchOne => 1,
      Model::BranchMany => 4,
      Model::BranchWithParentOne => 1,
      Model::BranchWithParentMany => 4,
      Model::LeafOneOne => 1,
      Model::LeafOneMany => 4,
      Model::LeafManyOne => 4,
      Model::LeafManyMany => 16
    }
    expected.each{|klass, count|
      expect([klass.name, klass.count]).to eq [klass.name, count]
    }
  end

  def node_events
    events_format *NodeNotification.events
  end
  def events_format *arr
    arr.map{|args|
      obj, arg = args
      type = (arg && arg[:type]) || :updated
      key = arg && arg[:key]
      ["#{obj.class.name}##{obj.id}", type, key]
    }.sort_by{|a|a.to_s}
  end

  it 'root' do
    root = Model::Root.first
    root.update name: 'aaa'
    expect(node_events).to eq events_format(
      [root],
      [root, key: ['branch_with_parent_one']],
      [root, key: ['branch_with_parent_manies']],
      [root, key: ['as_branch_with_parent_one']],
      [root, key: ['as_branch_with_parent_manies']]
    )
  end

  


end
