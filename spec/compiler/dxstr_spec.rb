require File.expand_path('../../spec_helper', __FILE__)

describe "A Dxstr node" do
  relates <<-ruby do
      t = 5
      `touch \#{t}`
    ruby

    compile do |g|
      g.push 5
      g.set_local 0
      g.pop

      g.push :self

      g.push_const :String

      g.push_literal "touch "
      g.push_local 0
      g.meta_to_s

      g.send_stack :interpolate_join, 2

      g.send :"`", 1, true
    end
  end
end
