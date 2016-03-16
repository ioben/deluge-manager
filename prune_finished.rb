require 'deluge'
require 'digest/md5'

require_relative 'media_directory'
require_relative 'classifier'

config = JSON.load(File.join(File.dirname(__FILE__), 'config.json'))

def escape_glob(s)
    s.gsub(/[\\\{\}\[\]\*\?]/) { |x| "\\"+x }
end

# Initialize client
client = Deluge::Rpc::Client.new(config['connection'])

client.connect

media_dir = MediaDirectory.new node['media_directory']

torrents = client.core.get_torrents_status({ }, ['name', 'hash', 'state', 'label'])

# Select additional information from seeding torrents
seeding_torrent_hashes = torrents.select{|h,t| t['state'] == 'Seeding'}.keys
seeding_torrents = client.core.get_torrents_status({ hash: seeding_torrent_hashes }, ['name', 'hash', 'state', 'label', 'files', 'ratio', 'seeding_time'])

torrents.merge! seeding_torrents


torrents_to_check = []
torrents_to_delete = []

torrents.each do |hash, torrent|
    puts
    print "#{torrent['name']} "

    next if torrent['state'] != 'Seeding'

    # Ignore torrents that haven't seeded for 2 days or to a ratio of 2.0
    if torrent['ratio'] < 2 and torrent['seeding_time'] < 60 * 60 * 24 * 2
        print "ignored"
        next
    end

    copied_files = []
    uncopied_files = []

    torrent['files'].each do |tfile|
        abs_filepath = Dir.glob(File.join(config['download_directory'], escape_glob(tfile['path'])))

        raise "Found multiple files for #{tfile['path']}" if abs_filepath.size > 1
        next if abs_filepath.size == 0
        abs_filepath = abs_filepath.first

        exists = media_dir.file_exists? abs_filepath
        tfile['type'] = Classifier.get_file_type tfile['path']

        copied_files.push(tfile) if exists
        uncopied_files.push(tfile) unless exists

        print "#{exists ? '+':'.'}"
    end
    print ' '

    if copied_files.size > 0
        if uncopied_files.select { |tfile| tfile['type'] == :video }.size > 0
            puts "Not all video files copied!!!"
            copied_files.each { |tfile| puts " + #{tfile['path']} (#{tfile['type']})" }
            uncopied_files.each { |tfile| puts " - #{tfile['path']} (#{tfile['type']})" }
        else
            puts "Files copied"
            torrents_to_delete.push torrent
        end
    else
        puts "Torrent files not copied!!!"
    end
end

puts
puts "Torrents to be deleted:"
torrents_to_delete.each do |torrent|
    puts "Removing: #{torrent['name']}"
    client.core.remove_torrent(torrent['hash'], true)
end

