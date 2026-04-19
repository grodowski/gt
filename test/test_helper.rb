# frozen_string_literal: true

require "simplecov"
require "undercover/simplecov_formatter"

SimpleCov.formatter = SimpleCov::Formatter::Undercover

SimpleCov.start do
  add_filter(/^\/test\//)
  add_filter("Rakefile")
  track_files "lib/**/*.rb"
  enable_coverage(:branch)
end

require "minitest/autorun"
require "fileutils"
require "tmpdir"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "gt"

CLI::UI.enable_color = false

module GitSandbox
  def setup
    @tmpdir = Dir.mktmpdir("gt-test-")
    @remote_dir = Dir.mktmpdir("gt-remote-")

    # Set up a bare remote
    system("git init --bare #{@remote_dir}", out: File::NULL, err: File::NULL)

    # Set up local repo
    @orig_dir = Dir.pwd
    Dir.chdir(@tmpdir)
    system("git init -b main", out: File::NULL, err: File::NULL)
    system("git config user.email 'test@test.com'", out: File::NULL, err: File::NULL)
    system("git config user.name 'Test'", out: File::NULL, err: File::NULL)
    system("git remote add origin #{@remote_dir}", out: File::NULL, err: File::NULL)

    # Initial commit so HEAD exists
    File.write("README.md", "init")
    system("git add -A", out: File::NULL, err: File::NULL)
    system("git commit -m 'init'", out: File::NULL, err: File::NULL)
    system("git push -u origin main", out: File::NULL, err: File::NULL)
  end

  def teardown
    Dir.chdir(@orig_dir)
    FileUtils.rm_rf(@tmpdir)
    FileUtils.rm_rf(@remote_dir)
  end

  def write_file(name, content = "content")
    File.write(name, content)
  end
end
