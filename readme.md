Deluge Manager
==============

Scripts used to help manage Deluge with a third-party renamer/copier (such as Sickbeard or Couchpotato).
Deluge Manager allows using the copy method inside Couchpotato or Sickbeard for media files so seeding works as expected, and the video files are organized correctly after they've finished downloading.  Deluge Manager checks each torrent managed by Deluge and verifies the torrent meets a set of rules (such as a minimum seed ratio or minimum time spent seeding).  If the torrent does, and the torrent files (specifically video files) are found in the given media directory (they've been copied by Couchpotato, Sickbeard, etc.), the torrent and its files (the originals still in the downloads directory) are deleted.

Usage
-----

0. Install ruby.  Tested with version `2.0.0p598`, the version that ships with RHEL 7.

1. Clone this repo into `/usr/local`

2. Copy the `config.example.json` to `config.json`

3. Configure `config.json` correctly.  Running `ruby deluge_manager` should work as expected.
   - You can add a new deluge API user to `/var/lib/deluge/.config/deluge/auth` with format `username:password:5`.

4. Create the following file `/etc/cron.d/deluge_manager`
```
0 0 * * * deluge /bin/ruby /usr/local/deluge-manager/prune_finished.rb | logger -p info -t deluge_manager
```
Note - You may need to replace `| logger -p info -t deluge_manager` with ` &> /var/log/deluge_manager.log` if you aren't on a system with systemd.
