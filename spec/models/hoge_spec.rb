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
        after_save :notify_destroy, on: :destroy
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

  it 'root' do
    root = Model::Root.first
    root.update name: 'aaa'
    one = root.branch_with_parent_one
    manies = root.branch_with_parent_manies

    events = [
      [root, data: root.to_notification_hash],
      [root, key: ['branch_with_parent_one', one.id], data: one.to_notification_hash],
      *manies.map{|child|
        [root, key: ['branch_with_parent_many',child.id], data: child.to_notification_hash]
      }
    ]
    expect(NodeNotification.events.size).to eq events.size
    binding.pry
  end


end
