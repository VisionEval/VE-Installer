# You can override VE_CONFIG, VE_LOGS, VE_RUNTESTS and VE_R_VERSION on the command line
# Or export them from your environment
VE_CONFIG?=config/VE-config.yml
VE_RUNTESTS?=Default
ifeq ($(OS),Windows_NT)
  VE_R_VERSION?=3.6.3
  RSCRIPT:="$(shell scripts/find-R.bat $(VE_R_VERSION))"
  WINDOWS=TRUE
else
  # If you change the PATH to point at a different Rscript, you can
  # support multiple R versions on Linux, but it's done outside the Makefile
  RSCRIPT:="$(shell which Rscript)"
  override VE_R_VERSION:=$(shell $(RSCRIPT) --no-init-file scripts/find-R.R)
  WINDOWS=FALSE
endif
ifeq ($(RSCRIPT),"")
  $(error R Version $(VE_R_VERSION) not found)
else
  $(info VE_R_VERSION is $(VE_R_VERSION), using [$(RSCRIPT)])
endif

export VE_R_VERSION VE_CONFIG VE_RUNTESTS RSCRIPT

VE_BRANCH?=$(shell basename $(VE_CONFIG) | cut -d'.' -f 1 | cut -d'-' -f 2-3)
VE_LOGS?=logs/VE-$(VE_R_VERSION)-$(VE_BRANCH)
VE_RUNTIME_CONFIG:=$(VE_LOGS)/dependencies.RData
VE_MAKEVARS:=$(VE_LOGS)/ve-output.make
export VE_LOGS VE_RUNTIME_CONFIG VE_MAKEVARS

VE_BOILERPLATE:=$(wildcard boilerplate/boilerplate*.lst)

include $(VE_MAKEVARS)
# $(VE_MAKEVARS) gets rebuilt (see below) if it is out of date, using build-config.R
# Make then auto-restarts to read:
#   VE_OUTPUT, VE_CACHE, VE_LIB, VE_INSTALLER, VE_PLATFORM, VE_TEST
#   and others

.PHONY: configure repository modules binary runtime installers all\
	clean lib-clean module-clean runtime-clean build-clean test-clean\
	dev-clean really-clean installer-clean\
        module-list runtime-packages\
	docker-clean docker-output-clean docker

all: configure repository binary modules runtime

show-defaults: $(VE_MAKEVARS)
	: Make defaults:
	: WINDOWS      $(WINDOWS)       # Running on Windows?
	: VE_PLATFORM  $(VE_PLATFORM)   # Then what platform ARE we running on?
	: VE_R_VERSION $(VE_R_VERSION)  # R Version for build
	: RSCRIPT      $(RSCRIPT)       # Rscript (should match R Version)
	: VE_LOGS      $(VE_LOGS)       # Location of log files
	: VE_CONFIG    $(VE_CONFIG)     # Location of VE-Config.yml
	: VE_MAKEVARS  $(VE_MAKEVARS)   # Make's version of VE-Config.yml
	: VE_OUTPUT    $(VE_OUTPUT)     # Root of build output
	: VE_DEPS      $(VE_DEPS)       # Location of dependency repository
	: VE_REPOS     $(VE_REPOS)      # Location of build VE packages (repo)
	: VE_LIB       $(VE_LIB)        # Location of installed packages
	: VE_RUNTIME   $(VE_RUNTIME)    # Location of local runtime
	: VE_TEST      $(VE_TEST)       # Location of test folder
	: VE_PKGS      $(VE_PKGS)       # Location of runtime packages (for installer/docker)

# Should have the "clean" target depend on $(VE_MAKEVARS) if it uses
# any of the folders like VE_OUTPUT that are read in from there.
build-clean: # Resets the built status of all the targets
	[[ -n "$(VE_LOGS)" ]] && rm -rf $(VE_LOGS)/*
	rm -f *.out

module-clean: $(VE_MAKEVARS) test-clean # Reset all VE modules for complete rebuild
	[[ -n "$(VE_REPOS)" ]] && rm -rf $(VE_REPOS)/*
	rm -rf $(VE_LIB)/visioneval $(VE_LIB)/VE*
	rm $(VE_LOGS)/modules.built

lib-clean: $(VE_MAKEVARS) # Reset installed package library for complete rebuild
	[[ -n "$(VE_LIB)" ]] && rm -rf $(VE_LIB)/*
	rm $(VE_LOGS)/velib.built

runtime-clean: $(VE_MAKEVARS) # Reset all models and scripts for complete rebuild
	[[ -n "$(VE_RUNTIME)" ]] && rm -rf $(VE_RUNTIME)/*
	[[ -n "$(VE_LOGS)" ]] && rm -f $(VE_LOGS)/runtime.built

test-clean: $(VE_MAKEVARS) # Reset the test copies of the packages
	[[ -n "$(VE_TEST)" ]] && rm -rf $(VE_TEST)/*

installer-clean: $(VE_MAKEVARS) # Reset the installers for rebuild
	# installers have the R version coded in their .zip name
	[[ -n "$(VE_OUTPUT)" ]] && [[ -n "$(VE_R_VERSION)" ]] && rm -f $(VE_OUTPUT)/$(VE_R_VERSION)/*.zip
	[[ -n "$(VE_PKGS)" ]] && rm -rf $(VE_PKGS)/*
	[[ -n "$(VE_LOGS)" ]] && rm -f $(VE_LOGS)/installer*.built

depends-clean: clean # Reset the CRAN, BioConductor and Github dependency packages for fresh download
	[[ -n "$(VE_DEPS)" ]] && rm -rf $(VE_DEPS)/*

dev-clean: $(VE_MAKEVARS) # Reset the developer packages for VE-Installer itself
	[[ -n "$(VE_R_VERSION)" ]] && rm -rf dev-lib/$(VE_R_VERSION)

clean: $(VE_MAKEVARS) build-clean test-clean # Reset everything except developer packages
	[[ -n "$(VE_OUTPUT)" ]] && [[ -n "$(VE_R_VERSION)" ]] && rm -rf $(VE_OUTPUT)/$(VE_R_VERSION)

really-clean: clean depends-clean dev-clean # Scorched earth: reset all VE-Installer artifacts

# The remaining targets build the various VisionEval pieces

# Make sure configuration is up to date
configure: $(VE_RUNTIME_CONFIG) $(VE_MAKEVARS)

# This rule reads the configuration about what to build. Use build-clean to reset
# Note: build-config.R identifies VE_CONFIG via the exported environment variable
$(VE_MAKEVARS) $(VE_RUNTIME_CONFIG): scripts/build-config.R $(VE_CONFIG) R-versions.yml
	mkdir -p $(VE_LOGS)
	mkdir -p dev-lib/$(VE_R_VERSION)
	[[ $(RSCRIPT) != "" ]] && $(RSCRIPT) scripts/build-config.R

# This rule and the following one rebuild the repository of dependencies for VE_R_VERSION
# Will skip if repository.built is up to date with VE_Config and the scripts themselves
repository: $(VE_LOGS)/repository.built

$(VE_LOGS)/repository.built: $(VE_RUNTIME_CONFIG) scripts/build-repository.R scripts/build-external.R
	$(RSCRIPT) scripts/build-repository.R
	$(RSCRIPT) scripts/build-external.R
	touch $(VE_LOGS)/repository.built

# This rule and the following one rebuild the installed library of dependencies and VE packages
# Will skip if velib.built is up to date with the repository build and with the script itself
# Use build-clean to reset velib.built and lib-clean to force complete rebuild of library
binary: $(VE_LOGS)/velib.built

$(VE_LOGS)/velib.built: $(VE_LOGS)/repository.built scripts/build-velib.R
	$(RSCRIPT) scripts/build-velib.R
	touch $(VE_LOGS)/velib.built

# This rule and the following one will check the VE modules and rebuild as needed
# We'll almost always "build" the modules but only out-of-date stuff gets built
# (File time stamps are checked in the R scripts)
modules: $(VE_LOGS)/modules.built

$(VE_LOGS)/modules.built: $(VE_LOGS)/repository.built $(VE_LOGS)/velib.built scripts/build-modules.R
	$(RSCRIPT) scripts/build-modules.R
	touch $(VE_LOGS)/modules.built

# This rule and the following one will (re-)copy out of date scripts and models to the runtime
# We'll almost always "build" the runtime, but only out-of-date stuff gets built
# (File time stamps are checked in the R scripts)
runtime: $(VE_LOGS)/runtime.built

$(VE_LOGS)/runtime.built: scripts/build-runtime.R $(VE_INSTALLER)/boilerplate/*
	$(RSCRIPT) scripts/build-runtime.R
	touch $(VE_LOGS)/runtime.built

# The next two rules will build the VisionEval Name Registry (listing
# all the modules and packages, and what their Inp and Set
# specifications are), and the Model Packages (listing which models
# use which modules from which packages). These are constructed
# programmatically from the VisionEval source tree.
# Results are place in VE_TEST

module-list: $(VE_TEST)/VENameRegistry.json $(VE_TEST)/VEModelPackages.csv #  $(VE_TEST)/module_status.csv

$(VE_TEST)/VENameRegistry.json $(VE_TEST)/VEModelPackages.csv: scripts/build-inventory.R $(VE_LOGS)/modules.built
	$(RSCRIPT) scripts/build-inventory.R

# The next rules build the installer .zip files
# 'bin' is the binary installer for the local architecture (e.g. Windows)
# 'src' is a multiplatform source installer (requires rebuilding packages on client side)
installers: installer-bin installer-src

installer installer-bin: $(VE_LOGS)/installer-bin.built

$(VE_LOGS)/installer-bin.built: $(VE_RUNTIME_CONFIG) $(VE_LOGS)/runtime.built  \
            scripts/build-runtime-packages.R scripts/build-installers.sh
	$(RSCRIPT) scripts/build-runtime-packages.R
	bash scripts/build-installers.sh BINARY
	touch $(VE_LOGS)/installer-bin.built

installer-src: $(VE_LOGS)/installer-src.built

$(VE_LOGS)/installer-src.built: $(VE_RUNTIME_CONFIG) $(VE_LOGS)/installer-bin.built \
            scripts/build-runtime-packages.R scripts/build-installers.sh
	$(RSCRIPT) scripts/build-runtime-packages.R source
	bash scripts/build-installers.sh SOURCE
	touch $(VE_LOGS)/installer-src.built

# Experimental Docker installation
# This will run, but the resulting images probably won't work (2019-05-24)
ifeq ($(WINDOWS),TRUE)
docker-output-clean docker-clean docker:
	echo Docker building is not available on Windows
else
export VE_OUTPUT VE_RUNTIME
export VE_DOCKER_IN=$(VE_INSTALLER)/docker
export VE_DOCKER_OUT=$(VE_OUTPUT)/$(VE_R_VERSION)/docker
export DOCKERFILE=$(VE_DOCKER_IN)/Dockerfile

docker-output-clean:
	sudo rm -rf ${VE_DOCKER_OUT}/Data # Files within are owned by 'root'
docker-clean: docker-output-clean
	rm -rf $(VE_DOCKER_OUT)/home
	
docker: $(VE_LOGS)/repository.built $(DOCKERFILE) $(VE_DOCKER_IN)/.dockerignore
	$(RSCRIPT) scripts/build-runtime-packages.R source
	bash scripts/build-docker.sh
endif
