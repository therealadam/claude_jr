# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "standard/rake"

require "steep/rake_task"
Steep::RakeTask.new do |t|
  t.check.severity_level = :error
  t.watch.verbose
end

namespace :pages do
  desc "Setup site directory and download CSS"
  task :setup do
    require "fileutils"
    site_dir = "_site"
    css_url = "https://raw.githubusercontent.com/edwardtufte/tufte-css/gh-pages/tufte.css"

    FileUtils.mkdir_p(site_dir)
    css_path = File.join(site_dir, "tufte.css")

    unless File.exist?(css_path)
      puts "Downloading tufte.css..."
      system("curl -o #{css_path} #{css_url}")
    end
  end

  desc "Check if pandoc is installed"
  task :check_pandoc do
    unless system("which pandoc > /dev/null")
      if RUBY_PLATFORM.include?("darwin")
        puts "Installing pandoc via Homebrew..."
        system("brew install pandoc")
      else
        puts "Installing pandoc via apt-get..."
        system("sudo apt-get update && sudo apt-get install -y pandoc")
      end
    end
  end

  desc "Build HTML from README"
  task build: [:setup, :check_pandoc] do
    title = "Claude, Jr. – a developer notebook"
    site_dir = "_site"

    cmd = [
      "pandoc README.md",
      "--standalone",
      "--metadata title=\"#{title}\"",
      "--css tufte.css",
      "--from gfm",
      "--to html5",
      "-o #{site_dir}/index.html"
    ].join(" \\\n  ")

    puts "Building HTML..."
    system(cmd)
    puts "Site generated: #{site_dir}/index.html"
  end
end

task default: %i[spec standard steep]
