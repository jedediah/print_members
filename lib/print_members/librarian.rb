
module PrintMembers
  module Librarian
    SEPARATOR_RE = Regexp.escape(::File::SEPARATOR)
    GEM_PATH_TO_NAME = ::Gem::QuickLoader::GemPaths.invert
    LIBRARY_FOR_PATH = {}

    class << self
      def library_for_path src
        LIBRARY_FOR_PATH[src] ||=
          if (defined? Gem) && (jem = Gem::QuickLoader::GemPaths.find {|x,path| src.start_with? path })
            [:gem,jem[0],Gem::QuickLoader::GemVersions[jem[0]]]
          elsif !(path = $LOAD_PATH.select {|p| src.start_with? p }).empty?
            base = path.max_by(&:size).split SEPARATOR_RE
            res = src.split SEPARATOR_RE
            [:lib,res[base.size].sub(/\.rb$/,''),nil] if res.size > base.size
          end
      end

      def ruby_files *path
        path = $LOAD_PATH if path.empty?

        if path.size == 1
          path = path[0]
          # one path given
          if File.exist?(path) && File.directory?(path)
            # we only care about directories that exist
            Dir.new(path).reject {|p|
              # filter out . and ..
              File.basename(p) =~ /^\.\.?$/
            }.map {|p|
              if File.directory?(p)
                # for a sub-dir, append it to the path and recurse
                # then prepend it to all the results
                ruby_files(File.join path, p).map {|x| File.join p, x }
              elsif p =~ /(.*)\.rb$/
                # a leaf node (ruby file)
                $1
              end
            }.compact.flatten # remove non-ruby files and flatten the recursive entries
          end
        else
          # multiple paths given, recurse for each one
          path.map {|p| ruby_files p }.flatten.uniq
        end
      end

      def libraries opts={}
        base = opts[:base] || $LOAD_PATH
        seen = opts[:seen] ||= {}
        libs = opts[:libs] ||= {}
        #puts opts.inspect
        if base.is_a? Array
          base.each {|lp|
            #puts "[base #{lp}]"
            libraries(opts.merge :base => lp)
          }
        else
          sub = opts[:sub] || ''
          full = File.join(base,sub)

          if !seen[full] && File.exist?(full)
            seen[full] = true

            if File.directory? full
              unless opts[:depth] && opts[:depth] <= 0
                #puts "[recurse sub=#{sub} full=#{full}]"
                Dir.new(full).reject{|p|
                  File.basename(p) =~ /^\.\.?$/
                }.each {|p|
                  libraries(opts.merge :sub => File.join(sub,p),
                                       :depth => (opts[:depth] ? opts[:depth]-1 : nil))
                }
              end
            elsif sub =~ /\.(rb|so|dll)$/
              #puts "[lib #{sub}]"
              libs[sub.gsub(/^\/|\.(rb|so|dll)$/,'')] = full
            end

          end
        end

        return opts[:libs]
      end # def libraries

    end # class << self
  end # module Librarian
end # module PrintMembers
