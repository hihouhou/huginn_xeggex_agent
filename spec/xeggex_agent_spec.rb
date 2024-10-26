require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::XeggexAgent do
  before(:each) do
    @valid_options = Agents::XeggexAgent.new.default_options
    @checker = Agents::XeggexAgent.new(:name => "XeggexAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
