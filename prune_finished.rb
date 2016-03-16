require 'json'
require 'digest/md5'
require 'deluge'

require_relative 'media_directory'
require_relative 'classifier'

config = nil
File.open(File.join(File.dirname(__FILE__), 'config.json'), 'r') do |filehandle|
    config = JSON.load(filehandle)
end

def escape_glob(s)
    s.gsub(/[\\\{\}\[\]\*\?]/) { |x| "\\"+x }
end

# Initialize
client = Deluge::Rpc::Client.new(Hash[config['connection'].map{|k,v| [k.to_sym,v]}])
media_dir = MediaDirectory.new config['media_directory']

# Connect and fetch basic metadata
client.connect

torrents = client.core.get_torrents_status({ }, ['name', 'hash', 'state', 'label'])


# Select additional information from torrents being seeded
# Must be done separately or torrents missing the requested information will break the RPC decoder in deluge-rpc package.
seeding_torrent_hashes = torrents.select{|h,t| t['state'] == 'Seeding'}.keys
seeding_torrents = client.core.get_torrents_status({ hash: seeding_torrent_hashes }, ['name', 'hash', 'state', 'label', 'files', 'ratio', 'seeding_time'])

torrents.merge! seeding_torrents

logger = Logger.new(STDOUT)
logger.level = Logger::INFO

torrents_to_delete = []

torrents.each do |hash, torrent|
    next if torrent['state'] != 'Seeding'

    # Ignore torrents that haven't seeded for 2 days or to a ratio of 2.0
    if torrent['ratio'] < 2 and torrent['seeding_time'] < 60 * 60 * 24 * 2
        logger.info "#{torrent['name']} ignored by ruleset."
        next
    end

    copied_files = []
    uncopied_files = []

    torrent['files'].each do |tfile|
        # Using the download_directory glob, attempt to resolve the absolute path for each file.
        abs_filepath = Dir.glob File.join(config['download_directory'], escape_glob(tfile['path']))

        raise "Found multiple files for #{tfile['path']}" if abs_filepath.size > 1
        next if abs_filepath.size == 0
        abs_filepath = abs_filepath.first

        exists = media_dir.file_exists? abs_filepath
        tfile['type'] = Classifier.get_file_type tfile['path']

        copied_files.push(tfile) if exists
        uncopied_files.push(tfile) unless exists
    end

    if copied_files.size > 0
        if uncopied_files.select { |tfile| tfile['type'] == :video }.size > 0
            logger.warn "#{torrent['name']} - not all video files copied!"
            copied_files.each { |tfile| logger.info " + #{tfile['path']} (#{tfile['type']})" }
            uncopied_files.each { |tfile| logger.warn " - #{tfile['path']} (#{tfile['type']})" }
        else
            logger.info "#{torrent['name']} - files copied."
            copied_files.each { |tfile| logger.debug " + #{tfile['path']} (#{tfile['type']})" }
            uncopied_files.each { |tfile| logger.debug " - #{tfile['path']} (#{tfile['type']})" }
            torrents_to_delete.push torrent
        end
    else
        logger.warn "#{torrent['name']} files not copied yet."
    end
end

torrents_to_delete.each do |torrent|
    logger.info "Removing #{torrent['name']} with files"
    client.core.remove_torrent(torrent['hash'], true)
end

