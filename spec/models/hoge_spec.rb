require 'spec_helper'

describe Model do
  before{
    Fixture.load
    Model.constants.each do |name|
      klass = Model.const_get name
      klass.class_eval{
        after_create :notify_create, on: :create
        after_update :notify_update, on: :update
        after_destroy :notify_destroy
      }
    end
    NodeNotification.clear
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
      arg ||= {}
      type = arg[:type] || :updated
      key = arg[:key].try(:map, &:to_s)
      ["#{obj.class.name}##{obj.id}", type, key]
    }.sort_by{|a|a.to_s}
  end
  def deep_compact hash
    rec = ->(hash){
      hash.compact.map{|a,b|
        [a,Hash===b ? rec[b] : b]
      }.to_h
    }
    rec[JSON.parse hash.to_json]
  end

  it 'root' do
    root = Model::Root.first
    root.update name: :aaa
    expect(node_events).to eq events_format(
      [root],
      [root, key: ['branch_with_parent_one']],
      [root, key: ['branch_with_parent_manies']]
    )
  end

  context 'branch' do
    it 'one' do
      root = Model::Root.first
      record = root.branch_one
      record.update name: :aaa
      expect(node_events).to eq events_format(
        [record],
        [root, key: ['branch_one']],
      )
    end
    it 'change one' do
      root = Model::Root.first
      root.branch_one.destroy
      NodeNotification.clear
      root.branch_one = Model::BranchOne.new
      expect(node_events).to eq events_format(
        [root, type: :created, key: ['branch_one']],
      )
    end
    it 'delete one' do
      root = Model::Root.first
      record = root.branch_one
      record.destroy
      expect(node_events).to eq events_format(
        [record, type: :deleted],
        [root, type: :deleted, key: ['branch_one']],
      )
    end
    it 'many' do
      root = Model::Root.first
      record = root.branch_manies.first
      record.update name: :aaa
      expect(node_events).to eq events_format(
        [record],
        [root, key: ['branch_manies', record.id]],
      )
    end
    it 'create many' do
      root = Model::Root.first
      record = root.branch_manies.create
      expect(node_events).to eq events_format(
        [root, type: :created, key: ['branch_manies', record.id]],
      )
    end
    it 'delete many' do
      root = Model::Root.first
      record = root.branch_manies.first
      record.destroy
      expect(node_events).to eq events_format(
        [record, type: :deleted],
        [root, type: :deleted, key: ['branch_manies', record.id]],
      )
    end
  end

  [
    ['root','branch_one', 'leaf_one_one'],
    ['root','branch_one', 'leaf_one_many'],
    ['root','branch_many', 'leaf_many_one'],
    ['root','branch_many', 'leaf_many_many']
  ].each do |rname, bname, lname|
    context lname do
      let(:klass){Model.const_get lname.camelize}
      let!(:leaf){klass.first}
      let!(:branch){leaf.send(bname)}
      let!(:root){branch.send(rname)}
      let(:branch_multiple){bname =~ /_many$/}
      let(:multiple){lname =~ /_many$/}
      let(:targets){
        ->(leaf){
          bkey = branch_multiple ? [bname.pluralize, branch.id] : [bname]
          lkey = multiple ? [lname.pluralize, leaf.id] : [lname]
          [
            [root,key: [*bkey, *lkey]],
            [branch,key: lkey],
            [leaf]
          ]
        }
      }
      it 'create' do
        data = JSON.parse(root.to_front_hash.to_json)
        unless multiple
          leaf.destroy
          NodeNotification.clear
        end
        newleaf = klass.create "#{bname}_id" => branch.id
        expect(node_events).to eq events_format(
          *targets[newleaf].reject{|a,b|a==newleaf}.map{|a,b|[a,(b||{}).merge(type: :created)]}
        )
        result = JSEval.eval_notification data, NodeNotification.events
        expect(deep_compact result['output']).to eq deep_compact(root.reload.to_front_hash)
        expect(result['errors']).to eq []
        expect(result['events']).to eq [
          lname, "#{lname}_name", bname,
          (lname.pluralize if multiple),
          (bname.pluralize if branch_multiple),
          rname
        ].compact.sort
      end

      it 'update' do
        data = JSON.parse(root.to_front_hash.to_json)
        leaf.update name: :aaa
        expect(node_events).to eq events_format(*targets[leaf])
        result = JSEval.eval_notification data, NodeNotification.events
        expect(deep_compact result['output']).to eq deep_compact(root.reload.to_front_hash)
        expect(result['errors']).to eq []
        expect(result['events']).to eq [
          lname, "#{lname}_name", bname,
          (lname.pluralize if multiple),
          (bname.pluralize if branch_multiple),
          rname
        ].compact.sort
      end

      it 'delete' do
        data = JSON.parse(root.to_front_hash.to_json)
        leaf.destroy
        expect(node_events).to eq events_format(
          *targets[leaf].map{|a,b|[a,(b||{}).merge(type: :deleted)]}
        )
        result = JSEval.eval_notification data, NodeNotification.events
        expect(deep_compact result['output']).to eq deep_compact(root.reload.to_front_hash)
        expect(result['errors']).to eq []
        expect(result['events']).to eq [
          lname, bname,
          (lname.pluralize if multiple),
          (bname.pluralize if branch_multiple),
          rname
        ].compact.sort
      end
    end
  end

end

