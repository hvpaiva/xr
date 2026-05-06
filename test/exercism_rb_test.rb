# frozen_string_literal: true

Dir[File.join(__dir__, "*_test.rb")].sort.each do |file|
  next if File.basename(file) == "exercism_rb_test.rb"

  require file
end
