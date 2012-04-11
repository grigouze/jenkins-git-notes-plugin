class GitNotesPublisher < Jenkins::Tasks::Publisher
  include Builder

  display_name "Publish build result as git-notes"

  def initialize(attrs = {})
  end

  ##
  # Runs before the build begins
  #
  # @param [Jenkins::Model::Build] build the build which will begin
  # @param [Jenkins::Model::Listener] listener the listener for this build.
  def prebuild(build, listener)
  end

  ##
  # Runs the step over the given build and reports the progress to the listener.
  #
  # @param [Jenkins::Model::Build] build on which to run this step
  # @param [Jenkins::Launcher] launcher the launcher that can run code on the node running this build
  # @param [Jenkins::Model::Listener] listener the listener for this build.
  def perform(build, launcher, listener)
    BuildContext.instance.set(build, launcher, listener) do
      git_updater = GitUpdater.new
      retries = Constants::CONCURRENT_UPDATE_RETRIES
      begin
        info "updating git notes"
        git_updater.update!
      rescue ConcurrentUpdateError => e
        if retries > 0
          warn "caught ConcurrentUpdateError while updating git notes, retrying (#{retries}x left)"
          retries -= 1
          retry
        else
          raise e
        end
      end
    end
  end
  
  # Return a hash representing the git note we want to add to HEAD
  private
  def build_note_hash(build)
    native = build.send(:native)
    built_on = native.getBuiltOnStr || "master"
    built_on = "master" if built_on.empty?
    time = Time.at(native.getTimeInMillis / 1000.0)
    duration = Time.now - time

    {
      :built_on => built_on,
      :duration => duration,
      :full_display_name => native.getFullDisplayName,
      :id => native.getId,
      :number => native.getNumber,
      :result => native.getResult.toString,
      :status_message => native.getBuildStatusSummary.message,
      :time => time,
      :url => native.getUrl
    }
  end
end
