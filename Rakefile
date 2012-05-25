module Xcode
  def self.clean(target)
    xcodebuild "clean", target
  end

  def self.build(target)
    xcodebuild "build", target
  end
  
  def self.xcodebuild(action, target)
    Dir.chdir "SqlSpiel" do
      system "xcodebuild", 
        "-target", target, 
        "-configuration", "Debug",
        action
    end
  end
end


desc "Run tests"
task :test do
  Xcode.build("SqlSpiel") 
  # &&
  # 
  # system("./build/Debug/M4TestRunner")
end

task :default => :test

task :clean do
  Xcode.clean "SqlSpiel"
  # Xcode.clean "SqlSpielM4TestRunner"
end

