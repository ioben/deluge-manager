class Classifier
    def self.get_file_type(filepath)
        formats = {
            video: %w[.webm .mkv .flv .vob .ogv .ogg .drc .gif .gifv .mng .avi .mov .qt .wmv .yuv .rm .asf .mp4 .m4p .m4v .mpg .mp2 .mpeg .mpe .mpv .mpg .mpeg .m2v .m4v .svi .3gp .3g2 .mxf .roq .msv .flv .f4v .f4p .f4a .f4b],
            subtitle: %w[.srt],
            info: %w[.txt .nfo .url]
        }

        format = 'leftover'
        formats.each do |cformat, exts|
            exts.each do |ext|
                format = cformat if filepath.end_with? ext
            end
        end

        if format == :video && filepath =~ /(sample)/i
            format = :video_sample
        end

        return format
    end
end
