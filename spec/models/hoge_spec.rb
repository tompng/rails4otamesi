require 'spec_helper'

describe Model do
  before{Fixture.load}
  it 'fixtures loaded' do
    expect(Model::Root.count).to be 1
    expect{Model::Root.first.update name: :name}.to raise_error
  end
end
