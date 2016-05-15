require "fpm/namespace"
require "fpm/package"
require "fpm/util"
require "fileutils"

require "pleaserun/cli"

# A pleaserun package.
#
# This does not currently support 'output'
class FPM::Package::PleaseRun < FPM::Package
  # TODO(sissel): Implement flags.
  
  require "pleaserun/platform/systemd"
  require "pleaserun/platform/upstart"
  require "pleaserun/platform/launchd"
  require "pleaserun/platform/sysv"

  option "--name", "SERVICE_NAME", "The name of the service you are creating"

  private
  def input(command)
    platforms = [
      ::PleaseRun::Platform::Systemd.new("default"), # RHEL 7, Fedora 19+, Debian 8, Ubuntu 16.04
      ::PleaseRun::Platform::Upstart.new("1.5"), # Recent Ubuntus
      ::PleaseRun::Platform::Upstart.new("0.6.5"), # CentOS 6
      ::PleaseRun::Platform::Launchd.new("10.9"), # OS X
      ::PleaseRun::Platform::SYSV.new("lsb-3.1") # Ancient stuff
    ]

    attributes[:pleaserun_name] ||= File.basename(command.first)
    attributes[:prefix] ||= "/usr/share/pleaserun/#{attributes[:pleaserun_name]}"

    platforms.each do |platform|
      logger.info("Generating service manifest.", :platform => platform.class.name)
      platform.program = command.first
      platform.name = attributes[:pleaserun_name]
      platform.args = command[1..-1]
      platform.description = attributes[:description]
      base = staging_path(File.join(attributes[:prefix], "#{platform.platform}/#{platform.target_version || "default"}"))
      target = File.join(base, "files")
      actions_script = File.join(base, "install_actions.sh")
      ::PleaseRun::Installer.install_files(platform, target, false)
      ::PleaseRun::Installer.write_actions(platform, actions_script)
    end

    libs = [ "install.sh", "install-path.sh", "generate-cleanup.sh" ]
    libs.each do |file|
      base = staging_path(File.join(attributes[:prefix]))
      File.write(File.join(base, file), template(File.join("pleaserun", file)).result(binding))
      File.chmod(0755, File.join(base, file))
    end

    scripts[:after_install] = template(File.join("pleaserun", "scripts", "after-install.sh")).result(binding)
    scripts[:before_remove] = template(File.join("pleaserun", "scripts", "before-remove.sh")).result(binding)
  end # def input

  public(:input)
end # class FPM::Package::PleaseRun
