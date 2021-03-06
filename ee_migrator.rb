#!/usr/bin/env ruby

# ---------------------------------------------------------------------
#
# Name      : ExpressionEngine2 MySQL Migrator
# Version   : 1.5.1
# URL       : https://github.com/tomdavies/expression-engine-2-migrator.ee_addon
# Adapted by: Tom Davies
# From      : https://github.com/srushe/expression-engine-migrator.ee_addon
# Author    : Stephen Rushe
#
# This work is licensed under the Creative Commons Attribution-Share
# Alike 3.0 Unported License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-sa/3.0/
#
# ---------------------------------------------------------------------

require 'optparse'

# ---------------------------------------------------------------------
# A simple helper method to see if we have valid options.
# ---------------------------------------------------------------------
def all_or_none_specified(first, second)
  first_specified  = (first.nil? or first == '') ? false : true
  second_specified = (second.nil? or second == '') ? false : true
  return !(first_specified ^ second_specified)
end

# ---------------------------------------------------------------------
# Deal with any command-line options.
# ---------------------------------------------------------------------
options = { :table_prefix => 'exp', :all_data => false }
OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"

  opts.on("-a", "--all_data",
          "Keep all data in the transformation") do |a|
    options[:all_data] = a
  end

  opts.on("-t", "--table_prefix [PREFIX]",
          "Specify the database table prefix") do |t|
    options[:table_prefix] = t || 'exp'
    options[:table_prefix].sub!(/_$/, '')  # Ensure extension doesn't end with a _
  end

  opts.on("-c", "--current_domain [DOMAIN NAME]",
          "Specify the domain name for the current site") do |c|
    options[:current_domain] = c
  end

  opts.on("-n", "--new_domain [DOMAIN NAME]",
          "Specify the domain name for the new site") do |n|
    options[:new_domain] = n
  end

  opts.on("-s", "--current_path [CURRENT SITE PATH]",
          "Specify the file system path to the current site") do |c|
    options[:current_path] = c
  end

  opts.on("-p", "--new_path [NEW SITE PATH]",
          "Specify the file system path to the new site") do |n|
    options[:new_path] = n
  end
end.parse!

# ---------------------------------------------------------------------
# Check that we have all of the data we require.
# ---------------------------------------------------------------------
valid_parameters = true

unless all_or_none_specified(options[:current_domain], options[:new_domain])
  $stderr.puts "You must specify either both domains or none"
  valid_parameters = false
end
unless all_or_none_specified(options[:current_path], options[:new_path])
  $stderr.puts "You must specify either both paths or none"
  valid_parameters = false
end
unless options[:table_prefix]
  $stderr.puts "Required option --table_prefix missing"
  valid_parameters = false
end

# ---------------------------------------------------------------------
# The web directories *must* be provided with starting slashes, unless
# they're empty. We'll add trailing ones if required though.
# ---------------------------------------------------------------------
[ :current_path, :new_path ].each do |opt|
  if options[opt]
    unless /^\//.match(options[opt])
      valid_parameters = false
      $stderr.puts "The option --#{opt} must have a leading slash"
    end
    options[opt] << '/' unless /\/$/.match(options[opt])
  end
end
exit unless valid_parameters

# ---------------------------------------------------------------------
# Store the parameters in nice little variables.
# ---------------------------------------------------------------------
table_prefix      = options[:table_prefix]
current_domain    = options[:current_domain]
new_domain        = options[:new_domain]
current_path      = options[:current_path]
new_path          = options[:new_path]

# -------------------------------------------------------------------
# Skip the rest of the changes unless the domain name or the site
# path has changed.
# -------------------------------------------------------------------
unless ((current_domain != new_domain) or (current_path != new_path))
  $stderr.puts "The domain or web path must be updated"
  exit
end

# ---------------------------------------------------------------------
# Do we have a file to process and does it exist?
# ---------------------------------------------------------------------
if ARGV[0].nil?
  $stderr.puts "You must specify a file"
  exit
end
filename = ARGV[0]

unless File.exist?(filename)
  $stderr.puts "The file #{filename} does not exist"
  exit
end

# ---------------------------------------------------------------------
# Open the database file for reading.
# ---------------------------------------------------------------------
db_file = File.new(filename, "r")

# ---------------------------------------------------------------------
# Process the lines one at a time.
# ---------------------------------------------------------------------
while (line = db_file.gets)
  line.chomp

  # -------------------------------------------------------------------
  # Skip unless it's an INSERT.
  # -------------------------------------------------------------------
  unless /^INSERT INTO /i.match(line)
    puts line
    next
  end

  # -------------------------------------------------------------------
  # Leave out certain lines unless we're keeping all data.
  # -------------------------------------------------------------------
  unless options[:all_data]
    next if /^INSERT INTO `?#{table_prefix}_captcha`?/i.match(line)
    next if /^INSERT INTO `?#{table_prefix}_cp_log`?/i.match(line)
    next if /^INSERT INTO `?#{table_prefix}_cp_search_index`?/i.match(line)
    next if /^INSERT INTO `?#{table_prefix}_email_cache(|_mg|_ml)`?/i.match(line)
    next if /^INSERT INTO `?#{table_prefix}_email_console_cache`?/i.match(line)
    next if /^INSERT INTO `?#{table_prefix}_email_tracker`?/i.match(line)
    next if /^INSERT INTO `?#{table_prefix}_mailing_list`? /i.match(line)
    next if /^INSERT INTO `?#{table_prefix}_mailing_list_queue`?/i.match(line)
    next if /^INSERT INTO `?#{table_prefix}_message_attachments`?/i.match(line)
    next if /^INSERT INTO `?#{table_prefix}_message_copies`?/i.match(line)
    next if /^INSERT INTO `?#{table_prefix}_message_data`?/i.match(line)
    next if /^INSERT INTO `?#{table_prefix}_message_listed`?/i.match(line)
    next if /^INSERT INTO `?#{table_prefix}_password_lockout`?/i.match(line)
    next if /^INSERT INTO `?#{table_prefix}_referrers`?/i.match(line)
    next if /^INSERT INTO `?#{table_prefix}_reset_password`?/i.match(line)
    next if /^INSERT INTO `?#{table_prefix}_search`?/i.match(line)
    next if /^INSERT INTO `?#{table_prefix}_search_log`?/i.match(line)
    next if /^INSERT INTO `?#{table_prefix}_security_hashes`?/i.match(line)
    next if /^INSERT INTO `?#{table_prefix}_sessions`?/i.match(line)
    next if /^INSERT INTO `?#{table_prefix}_throttle`?/i.match(line)
  end
  
  # -------------------------------------------------------------------
  # If we're dealing with an INSERT into a table which uses serialised
  # data then we need to perform some recalculation of the offset.
  # -------------------------------------------------------------------
  if /^INSERT INTO `?#{table_prefix}_(extensions|relationships|sites)`?/i.match(line)
    
    # -----------------------------------------------------------------
    # Replace the domain name if it has changed.
    # -----------------------------------------------------------------
    if (current_path and (current_path != new_path))
      while matches = /(\}|;)s:(\d+):\\"#{current_path.gsub('/', '\/')}(.*?)\\";/.match(line)
        full_match      = matches[0]
        start_char      = matches[1]
        characters      = matches[2]
        post_domain_str = matches[3]

        replacement_string  = "#{start_char}s:#{characters.to_i + new_path.length - current_path.length}:"
        replacement_string << "\\\"#{new_path}#{post_domain_str}\\\";"
        line.gsub!(/#{Regexp.escape(full_match)}/, replacement_string)
      end
    end

    if (current_domain and (current_domain != new_domain))
      # ---------------------------------------------------------------
      # What string should we check for when looking for the current
      # domain?
      # ---------------------------------------------------------------
      current_domain_re = /^http:\/\//.match(current_domain) ? Regexp.new(/#{current_domain}/) : Regexp.new(/http:\/\/#{current_domain}/)

      # ---------------------------------------------------------------
      # What string should we replace the current domain with?
      # ---------------------------------------------------------------
      new_domain_string = /^http:\/\//.match(new_domain) ? new_domain : "http://#{new_domain}"
                                     
      while matches = /(\}|;)s:(\d+):\\"#{current_domain_re}(.*?)\\";/i.match(line)
        full_match      = matches[0]
        start_char      = matches[1]
        characters      = matches[2]
        post_domain_str = matches[3]
        
        replacement_string  = "#{start_char}s:#{characters.to_i + new_domain.length - current_domain.length}:"
        replacement_string << "\\\"#{new_domain_string}#{post_domain_str}\\\";"
        line.gsub!(/#{Regexp.escape(full_match)}/, replacement_string)
      end
    end
    
  # -------------------------------------------------------------------
  # If we're dealing with an INSERT into a table which doesn't use
  # serialised data then we can do a simple replace.
  # -------------------------------------------------------------------
  else
    if current_path and (current_path != new_path)
      line.gsub!(/#{current_path.gsub('/', '\/')}/, "#{new_path}")
    end
    if current_domain and (current_domain != new_domain)
      line.gsub!(/#{current_domain}/, "#{new_domain}")
    end
  end

  # -------------------------------------------------------------------
  # Print out the converted line.
  # -------------------------------------------------------------------
  puts line
end
