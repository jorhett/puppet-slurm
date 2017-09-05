################################################################################
# Time-stamp: <Tue 2017-09-05 17:24 svarrette>
#
# File::      <tt>repo.pp</tt>
# Author::    UL HPC Team (hpc-sysadmins@uni.lu)
# Copyright:: Copyright (c) 2017 UL HPC Team
# License::   Apache-2.0
#
# ------------------------------------------------------------------------------
# = Class: slurm::repo
#
# This class takes care of the control repository for the slurm configuration, which
# version your slurm configuration files.
# For many reasons, we decided NOT to directly version the /etc/slurm directory,
# but rather to have a control repository cloned in another directory and
# following a specific layout depicted below:
#
# * for the cluster '${clustername}', a root directory named'${clustername}'
#   hosts all common slurm configuration files
# * a script '${syncscript}' (typically 'bin/commit_slurm_configs.sh') is
#   responsible for synchronizing the configuration and commit it into this
#
#   .
#   ├── bin/
#   |    └── commit_slurm_configs.sh
#   └── <clustername>/
#          ├── cgroup.conf
#          ├── gres.conf
#          ├── plugstack.conf
#          ├── plugstack.conf.d
#          │   └── x11.conf
#          ├── slurm.conf
#          └── topology.conf
#
#
# Also, this server is expected to have push writes on the branch 'server/${::hostname}'
#
# @param ensure       [String]  Default: 'present'
#          Ensure the presence (or absence) of the repository
# @param provider     [String]  Default: 'git'
#          Specifies the backend to use for this vcsrepo resource.
#          Valid options: 'bzr', 'git', 'hg', and 'svn'.
# @param basedir      [String]  Default: '/usr/local/src/git'
#          Base directory where to clone the repository
# @param path         [String]  Default: ''
#          Specifies a location for the managed repository.
#          It this stays empty, the repository will be cloned under $basedir/$namespace/$reponame
# @param source       [String or Hash]
#          Specifies a source repository to serve as the upstream for your managed repository.
#          Typically a Git repository URL or a hash of remotename => URL mappings
# @param branch       [String]  Default: 'HEAD'
#          The branch/revision to pull
#
# @example Clone the SLURM control repository into '/usr/local/src/git/ULHPC/slurm'
#
# class { 'slurm::repo':
  #     ensure => 'present',
  #     source => 'ssh://git@gitlab.uni.lu:8022/ULHPC/slurm.git',
  #  }
#
class slurm::repo(
  String $ensure   = $slurm::params::ensure,
  String $provider = 'git',
  String $basedir  = $slurm::params::repo_basedir,
  String $path     = '',
  $source          = undef,
  String $branch   = 'HEAD',
  String $syncscript = ''
)
inherits slurm::params
{
  validate_legacy('String',  'validate_re',   $ensure, ['^present', '^absent', '^latest'])
  validate_legacy('String',  'validate_re',   $provider, ['^git', '^bzr', '^hg', '^svn'])

  if ($source == undef or empty($source)) {
    fail("Module ${module_name} requires a valid source to clone the SLURM control repository")
  }

  $reponame =  basename($source, ".${provider}")
  $institute = basename(dirname($source))

  $real_path = $path ? {
    ''      => "${basedir}/${institute}/${reponame}",
    default => $path,
  }
  $user = defined(Class[::slurm]) ? {
    true    => $slurm::username,
    default => 'root',
  }
  $group = defined(Class[::slurm]) ? {
    true    => $slurm::group,
    default => 'root',
  }


  if $ensure == 'present' {
    exec { "mkdir -p ${real_path}":
      path   => '/sbin:/usr/bin:/usr/sbin:/bin',
      unless => "test -d ${real_path}",
      before => File[$real_path],
    }
    if !defined(File[$real_path]) {
      file { $real_path:
        ensure => 'directory',
        owner  => $user,
        group  => $group,
        mode   => $slurm::params::configdir_mode,
      }
    }
  }
  else {
    file { $real_path:
      ensure => $ensure,
      force  => true,
    }
  }
  # notice($source)
  # notice($real_path)

  vcsrepo { $real_path:
    ensure   => $ensure,
    provider => $provider,
    source   => $source,
    user     => $user,
    revision => $branch,
  }



}