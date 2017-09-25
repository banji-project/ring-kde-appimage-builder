# Semi generic alternative appimage generator for Ring-KDE

This repository provide my work on fixing some recurring issues with
the "usual" way of building KF5 based AppImages. While the current way
generally works fine, it has subtle issues that render ir hard for
multi-process apps such as Ring-KDE to be bundled:

 * Leaky self-containment: Some KDE frameworks start daemon automatically.
  While it generally works, some older/incompatible IPC between versions
  exeists (ex: KIO plugins and KDED5). If an AppImage is started before
  the system daemon, it will use its own bundled copy and this can cause
  issues
 * Multi-process nightmare: If the Ring daemon is already installed and
  running, it can cause data loss. If the Gnome client is installed and
  the AppImage Ring daemon is running, it will cause data loss.
 * Hardware issues: Video acceleration and other libs are picky about
  their base systems. This causes crashes or broken video.
 * Unversioned dependencies: Some internal dependencies of the stack have
  unstable ABIs (and APIs). Even when the symbols are compatible, the
  behavior might not be.
 * Unsustainable numbers of dependencies and `#if` preprocessors: Some
  packages are deprecating and replacing APIs at a rapid pace. Libraries
  such as LibAv, pjproject and GnuTLS tend to iterate more quickly than
  the oldest base system version. As the code perform static version check
  when compiled to select which code path to use, using system libraries
  is not a good idea. The newer code paths are usually faster and more
  future proof. While AppImages can bundle them from PPAs it has many
  tradeoffs.
 * Uncontrolled and exponential complexity: Ubuntu packages tend to pull
  a lot more dependencies compared to what's really required. Gentoo has
  the USE flag concept to disable optional packages, but, by default,
  Ubuntu does not.
 * Scary large image size: The "naive" image I first built had over 10k
  files and was near 1GB in size. Nobody will download that much just to
  try something.
 * Unpredictable ENV: Some users will do wierd thing to their computers.
  Its the joy of Linux. Assuming a setup because every base systems do it
  by default is wrong since it can be changed later. A good example is the
  init system or the audio system (or AUTH, DNS, Logs, file system, etc).
  Some existing AppImages already fail for me because I got creative. While
  it's my fault, assuming I am the only one is being naive.
 * Failed previous attempt: There was a lot of work in the past to make this
  work. However it grew into an unmaintainable and unscalable Docker image
  that stopped working almost every week due to the fragile dependency
  pyramid and moving targets. Even doing quick fixes to keep it working
  didn't seem to viable options. The problems need to be solved at their
  root and not mitigated from the top.

Current solutions:

 * Reduce the number of KF5 "hard" dependencies: A work in progress
  patchset already remove Qt5::Test and (partially) KIO as hard
  dependencies for some KF5 libraries. Future work could be done
  to allow more "useless" dependencies to be disabled if the final
  application has no use for them.
 * Split the "compilation" and "runability" capabilities. In a
  perfect world, the AppImage should be built in a sandbox so
  restricted it cannot even run executable. This reduce the
  maintainability cost as less differences between the various
  base systems (Ubuntu vs. SuSE) affect the final image.
 * Reduce the "attack surface": Switch to static versions where
  possible. Use the static Qt version with most modules disabled.
  Build all dependencies into each libraries.
 * Squash all 3 layers into 1: Get rid of the daemon and use the
  `libring` directly. This solve the multiple version issues.
 * Build all libring dependencies. 14.04 is too old anyway. Even
  with good will, mixing "old" libs with the required newer one
  created an untested (and untestable) mix. It was /running/, but
  there were very visible bugs. The libraries version used are the
  same mix as macOS and Windows. This shares the Q/A cost with those
  platforms.
 * Use a parent CMake project instead of a mile long command line:
  CMake supports adding subproject in an higher level projects. I
  made use of this feature to properly setup the environment without
  having to set varibles in the base image or use a gigantic command
  line. One of the upside of this is that it can eventually be
  modularized into a shared ECM module. This moves the support
  into KF5 instead of having to mitigate all corner case.

Work in progress solutions:

 * Add static library support to KF5:
 * Merge bundled static libraries support in ECM:
 * Agressive dead code elimination: Once the static work is done, it
  will be possible to reduce the AppImage size by 60-90% by removing
  all functions unused by the app. This is currently impossible with
  shared library as the information required only exists when a single
  process "own" all code. It is also a security feature since is makes
  ROP (return oriented programming) harder to exploit and also make
  some randomization easier.
 * Profile guided optimization: Once everything is owned by a single
  binary, it is possible to teach the compiler how the application is
  used. This improves performace by up to 30% (mostly during load time).
 * Move to musl LibC and a static libstdc++. This will mostly fix the
  need to build the image on an ancient distribution. This, in turn,
  allows better tooling with less effort. For now I use a PPA with
  the newer tools.

FAQ:

 * This seems complex!: If it was simple, an image would have been
  available months ago.
 * You could have skipped some steps and it would have worked anyway!:
  No. It would (and did) work on *most* systems, but not all. I tried,
  there was bugs. The naive version of the appimage could not be shipped.
  If it doesn't work on all systems and isn't stable, there is no point
  in doing an appimage.
 * Other appimages use X/Y/Z way or doing something, but you ignore
  that, why?: Many of the issues mentionned have been discussed with
  other dev. I/we wish for a programmer solution instead of a DevOps
  one. Most of the issues are also what prevent many applications
  from working correctly in FlatPak/Snap/Android/Windows. Having
  a solution reduces the work duplication and is eventually necessary.
  Better bite the bullet rather than having an unsustainable level of
  duplication across platforms. We don't have the manpower to do that
  work. Plus, the direction I am taking is closer to the "state of the
  art" of the container world. See the rise of Alpine Linux based
  containers and why it is a better model for shipping self contained
  projects. I am not claiming it was the only way. I am also not
  claiming some of the recommanded ways would not have worked (but
  *some* would not have). My point was that after looking into the
  problems, I am under the impression solving them at a lower level
  is more sustainable and beneficial for Ring-KDE and KF5 based apps
  in general.
 * This look too generic, how much did you waste of useless generic
  abstractions?: Lets be honest: some. However a rather small fraction
  compared to what had to be done one way or another. The KF5 patches
  are also the first step toward real support for sandboxed and/or
  self contained systems. So far it was relagated to an unscalable
  devops problem.
 * You are aware your image is needlessly huge, right? Yes, I am. Until
  all KF5 libraries support static versions, they will bundle copies of
  that that do. This create a lot of duplication in uncompressed images.
  The stated goal of reducing the image size it currently going in the
  wrong direction until the conditions are met to run on DCE and PGO.
  Maybe also allowing to download different images per l10n profile
  would help (for ~52mb). Firefox and Libreoffice do it. But the DCE
  will be necessary.
 * Did you write all that from scratch in the last week? No, I re-used
  some code (I own) from one of my Android compatible app. I did however
  port the code from bash to cmake.
