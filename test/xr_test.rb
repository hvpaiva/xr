# frozen_string_literal: true

Dir[File.join(__dir__, "*_test.rb")].sort.each do |file|
  next if File.basename(file) == "xr_test.rb"

  require file
end
