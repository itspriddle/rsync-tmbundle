#!/usr/bin/env ruby
require ENV['TM_SUPPORT_PATH'] + '/lib/web_preview'
require ENV['TM_SUPPORT_PATH'] + '/lib/escape'
require ENV['TM_SUPPORT_PATH'] + '/lib/osx/plist'

module Rsync
  class ConfigError < StandardError; end
  PLFILE = ENV['HOME'] + '/Library/Preferences/com.macromates.textmate.plist'
  PLKEY  = 'rsync.tmbundle Credentials'
  WINDOW = e_sh File.join(ENV['TM_BUNDLE_SUPPORT'], 'nibs/rsync.nib')
  DIALOG = e_sh ENV['DIALOG']

  CONFIG = OSX::PropertyList.load(File.read(PLFILE))[PLKEY] || {}
  CONFIG.merge!({
    'SSH_KEY'            => ENV['SSH_KEY'],
    'SSH_USER'           => ENV['SSH_USER'],
    'SSH_HOST'           => ENV['SSH_HOST'],
    'SSH_REMOTE_PATH'    => ENV['SSH_REMOTE_PATH'],
    'RSYNC_OPTIONS'      => ENV['RSYNC_OPTIONS'],
    'RSYNC_EXCLUDE_FROM' => ENV['RSYNC_EXCLUDE_FROM']
  }.delete_if { |key, val| val.nil? })

  extend self

  def execute!
    print_html rsync!
  rescue ConfigError
    msg = "SSH_HOST and SSH_REMOTE_PATH must be set to continue"
    print_html(msg, true)
  end

  def ask_for_config!
    res = %x{#{DIALOG} -p '#{CONFIG.to_plist}' -q #{WINDOW}}
    CONFIG.merge!(OSX::PropertyList.load(res))
    save_config
  end

  private

  def print_html(output, error = false)
    html_header 'rsync Project'
    # things went okay
    if error
      puts "<h3>Error:</h3>"
    else
      puts "<h3>rsync command:</h3>"
      puts "<pre>#{command}</pre>"
      puts "<h3>Output:</h3>"
    end

    puts "<pre>#{output}</pre>"

    html_footer
  end

  def configured?
    CONFIG['SSH_HOST'] && CONFIG['SSH_REMOTE_PATH']
  end

  def save_config
    plist = OSX::PropertyList.load(File.read(PLFILE))
    plist[PLKEY] = CONFIG
    File.open(PLFILE, 'w') do |io|
      OSX::PropertyList.dump(io, plist)
    end
  end

  def rsync!
    if configured?
      %x{#{command}}
    else
      raise ConfigError
    end
  end

  def command
    return @command if @command

    project = ENV['TM_PROJECT_DIRECTORY']

    if CONFIG['SSH_KEY'] && CONFIG['SSH_KEY'] != ""
      ssh = "ssh -i #{CONFIG['SSH_KEY']}"
    else
      ssh = "ssh"
    end

    opts = '-auv'

    if CONFIG['RSYNC_OPTIONS'] && CONFIG['RSYNC_OPTIONS'] != ""
      opts += " #{CONFIG['RSYNC_OPTIONS']}"
    end

    if CONFIG['RSYNC_EXCLUDE_FROM'] && CONFIG['RSYNC_EXCLUDE_FROM'] != ""
      exclude = CONFIG['RSYNC_EXCLUDE_FROM']
      if File.exists?(exclude)
        opts += " --exclude-from=#{exclude}"
      elsif File.exists?(File.join(project, exclude))
        opts += " --exclude-from=#{File.join(project, exclude)}"
      end
    end

    remote = "#{CONFIG['SSH_HOST']}:#{CONFIG['SSH_REMOTE_PATH']}"

    if CONFIG['SSH_USER'] && CONFIG['SSH_USER'] != ""
      remote = "#{CONFIG['SSH_USER']}@#{remote}"
    end

    @command = %{rsync -e "#{ssh}" #{opts} "#{project}"/ "#{remote}"}
  end

end
