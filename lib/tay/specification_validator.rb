module Tay
  ##
  # Takes a Tay::Specification and does sanity checks for missing required
  # fields. It also looks for common mistakes and mutually exclusive flags.
  #
  # If the output directory is supplied (referencing the compiled extension),
  # the existence of files referenced in the specification will also be checked
  # for their presence.
  class SpecificationValidator
    ##
    # Pointer to the relevant Tay::Specification
    attr_reader :spec

    ##
    # If true (default) throw an exception on error
    attr_accessor :violent

    ##
    # A proc object that will be called on each message with the type and msg
    attr_accessor :on_message

    attr_reader :warnings
    attr_reader :errors

    ##
    # Convenience method to validate a specification. Creates a validator and
    # runs it. Will throw an exception if invalid.
    def self.validate(specification, output_directory = nil)
      validator = SpecificationValidator.new(specification, output_directory)
      validator.violent = true
      validator.validate!
    end

    def initialize(specification, output_directory = nil)
      @spec = specification
      @out = output_directory ? Pathname.new(output_directory) : nil
      @errors = []
      @warnings = []
    end

    ##
    # Facade method to call the private validation methods. Will return true if
    # there were no warnings or errors
    def validate!
      validate_name
      validate_version
      validate_icons
      validate_description

      check_for_browser_ui_collisions

      check_file_presence if @out

      @warnings.empty? && @errors.empty?
    end

    protected

    ##
    # Go through the specification checking that files that are pointed to
    # actually exist
    def check_file_presence
      spec.icons.values.each do |path|
        fail_if_not_exist "Icon", path
      end

      if spec.browser_action
        fail_if_not_exist "Browser action popup", spec.browser_action.popup
        fail_if_not_exist "Browser action icon", spec.browser_action.icon
      end

      if spec.page_action
        fail_if_not_exist "Page action popup", spec.page_action.popup
        fail_if_not_exist "Page action icon", spec.page_action.icon
      end

      if spec.packaged_app
        fail_if_not_exist "App launch page", spec.packaged_app.page
      end

      spec.content_scripts.each do |content_script|
        content_script.javascripts.each do |script_path|
          fail_if_not_exist "Content script javascript", script_path
        end
        content_script.stylesheets.each do |style_path|
          fail_if_not_exist "Content script style", style_path
        end
      end

      spec.background_scripts.each do |script_path|
        fail_if_not_exist "Background script style", script_path
      end

      fail_if_not_exist "Background page", spec.background_page
      fail_if_not_exist "Options page", spec.options_page

      spec.web_intents.each do |web_intent|
        fail_if_not_exist "Web intent href", web_intent.href
      end

      spec.nacl_modules.each do |nacl_module|
        fail_if_not_exist "NaCl module", nacl_module.path
      end

      spec.web_accessible_resources.each do |path|
        fail_if_not_exist "Web accessible resource", path
      end
    end

    def validate_name
      fatal("No name provided") unless spec.name
      fatal("Name too long") if spec.name.length > 45
    end

    def validate_version
      fatal("No version provided") unless spec.version
      fatal("Invalid characters in version") if spec.version[/[^0-9\.]/]
    end

    def validate_icons
      warn("No icons provided") if spec.icons.keys.empty?
    end

    def validate_description
      fatal("Description too long") if spec.description && spec.description.length > 132
    end

    def check_for_browser_ui_collisions
      count = 0
      count += 1 if spec.packaged_app
      count += 1 if spec.page_action
      count += 1 if spec.browser_action

      if count > 1
        fatal('Only one of browser_action, page_action, and packaged app can be specified')
      end
    end

    def check_for_background_collisions
      if spec.background_page && spec.background_scripts.length > 0
        fatal("You cannot use both background pages and background scripts")
      end
    end

    private

    def fatal(msg)
      @errors << msg
      unless on_message.nil?
        on_message.call('fatal', msg)
      end
      raise Tay::InvalidSpecification.new if violent
    end

    def warn(msg)
      @warnings << msg
      unless on_message.nil?
        on_message.call('warn', msg)
      end
    end

    def fail_if_not_exist(what, path)
      fatal("#{what} does not exist at '#{path}'") unless !path || @out.join(path).exist?
    end
  end

end