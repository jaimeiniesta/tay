module Tay
  module CLI
    class Root < ::Thor
      desc 'validate', 'Validate the current extension'
      method_option :tayfile, :type => :string,
        :banner => 'Use the specified tayfile instead of Tayfile'
      method_option 'built-directory', :type => :string, :default => 'build',
        :aliases => '-b', :banner => 'The directory containing the built extension'
      def validate
        spec = get_specification
        build_dir = Pathname.new(options['built-directory']).expand_path(tayfile_path.dirname)

        validator = SpecificationValidator.new(spec, build_dir)
        validator.on_message = lambda do |type, message|
          say(type.upcase + ": " + message, type == 'warn' ? :yellow : :red)
        end

        if validator.validate!
          say("All OK!", :green)
        end
      end
    end
  end
end