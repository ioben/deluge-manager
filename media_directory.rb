class MediaDirectory
    def initialize(directory)
        @directory = directory
        @files = {}

        scan_file_sizes!
    end


    # Given the path to a file, check if it exists in MediaDirectory's directory.
    #
    # * Checks first with size of file, then a hash (using compute_file_hash).
    def file_exists?(filepath)
        cfilesize = File.stat(filepath).size

        files_with_correct_size = @files.select { |filepath,f| f[:size] == cfilesize }

        # Fail now if no files of equal size are found
        return false unless files_with_correct_size.length > 0

        cfilehash = compute_file_hash filepath

        # Compute and cache hashes for all files which could potentially match the one being searched for.
        files_with_correct_size.select { |_,f| f[:hash].nil? }.each { |filepath, _| @files[filepath][:hash] = compute_file_hash filepath }

        @files.select { |_,f| f[:hash] == cfilehash }.size > 0
    end


    private
    # Cache metadata of files in the directory being managed.
    def scan_file_sizes!
        Dir.glob(File.join(@directory, '**/*')) do |filepath|
            next if File.directory? filepath

            @files[filepath] = {
                path: filepath,
                size: File.stat(filepath).size,
                type: Classifier.get_file_type(filepath),
                hash: nil
            }
        end
    end

    # Computes a hash of a file given its filepath, only compares up to first 100MB of file.
    def compute_file_hash(filepath)
        count = 0
        md5 = Digest::MD5.new
        File.open(filepath, 'rb') do |filehandle|
            while buffer = filehandle.read(1024*1024*10)
                md5 << buffer
                count += 1
                break if count > 10
            end
        end

        md5.digest
    end
end
