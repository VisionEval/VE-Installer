#!/bin/env Rscript

# Author: Jeremy Raw

# This script downloads required R packages from CRAN and BioConductor into the
# local pkg-repository

# Load runtime configuration
source(file.path(getwd(),"scripts/get-runtime-config.R"))

# uncomment the following line on Windows if you just want the pre-compiled
# binaries otherwise, if RTools is installed the newer sources packages will be
# compiled.  You should allow compilation to happen if there is discrepancy in
# behavior between a Windows installation and a source (e.g. Linux/Docker)
# installation
options(install.packages.compile.from.source="never")

# Load required libraries
if ( ! suppressWarnings(require(miniCRAN)) ) {
  install.packages("miniCRAN", repos=CRAN.mirror, dependencies=NA, type=.Platform$pkgType)
}

require(tools)

cat("========== BUILDING DEPENDENCY REPOSITORY (CRAN / BioConductor ==========\n")

# BioConductor setup
# if ( ! requireNamespace("BiocManager") ) {
#     install.packages("BiocManager", repos=CRAN.mirror)
# }
# bioc <- BiocManager::repositories()
bioc <- BioC.mirror

if ( ! exists("pkgs.CRAN") || ! exists("pkgs.BioC") || ! exists("pkgs.db") ) {
  stop("Please run build-config.R to build dependency lists")
}

# Base R packages (so we can ignore those as dependencies)
base.lib <- dirname(find.package("MASS")) # looking for recommended packages; picking one that is required
pkgs.BaseR <- as.vector(installed.packages(lib.loc=base.lib, priority=c("base", "recommended"))[,"Package"])

# Fix up any partially complete repository stuff (this will happen, e.g., if build-repository.R is interrupted)
# And it will save us re-downloading packages that happen already to be in the repository.

# A couple of helper functions
# havePackages: check for presence of basic repository structure
# findMissingPackages: list packages not present in a particular sub-repository

havePackages <- function() {
  # Determine if pkg-repository is well-formed
  #
  # Returns:
  #   TRUE/FALSE depending on existence of pkg-repository file tree
  #
  # If the tree is there, don't need to build the miniCRAN from scratch
  src.contrib <- contrib.url(ve.dependencies, type="source")
  got.src <- FALSE
  if ( dir.exists(file.path(ve.dependencies, "src")) ) {
    if ( ! file.exists(file.path(src.contrib, "PACKAGES")) ) {
      cat("Updating VE repository source PACKAGES files\n")
      got.src <- (write_PACKAGES(src.contrib, type="source")>0)
    } else {
      got.src <- TRUE
    }
  }

  if ( ve.binary.build) {
    bin.contrib <- contrib.url(ve.dependencies, type=ve.build.type)
    got.bin <- FALSE
    if ( dir.exists(file.path(ve.dependencies, "bin")) ) {
      if ( ! file.exists(file.path(bin.contrib, "PACKAGES")) ) {
        cat("Updating VE repository ",ve.build.type," PACKAGES files\n")
        got.bin <- (write_PACKAGES(bin.contrib, type=ve.build.type)>0)
      } else {
        got.bin <- TRUE
      }
    }
  }

  got.src && ( ! ve.binary.build || got.bin )
}

findMissingPackages <- function( required.packages ) {
  # Determine if any packages are missing from the pkg-repository
  # compared to the required.packages passed in.
  #
  # Args:
  #   required.packages: a character vector containing names of packages
  #                      we hope to find in pkg-repository
  #
  # Returns:
  #   A list with two named elements 'bin' and 'src' each containing
  #   a character vector of package names that are missing from the
  #   respective sections of the pkg-repository compared to the
  #   required.packages
  aps <- available.packages(repos=ve.deps.url, type="source")
  if ( ve.binary.build ) apb <- available.packages(repos=ve.deps.url, type=ve.build.type)
  list(
    src=setdiff( required.packages, aps[,"Package"]),
    bin=if ( ve.binary.build ) setdiff( required.packages, apb[,"Package"]) else character(0)
    )
}

cat("\nComputing dependencies.\n")
pkgs.CRAN.all <- pkgs.CRAN.lst <- miniCRAN::pkgDep(pkgs.db$Package[pkgs.CRAN], repos=CRAN.mirror, suggests=FALSE)
pkgs.CRAN.lst <-  setdiff(pkgs.CRAN.lst, pkgs.BaseR) # don't keep base packages
cat("pkgs.CRAN.all\n")
print(sort(pkgs.CRAN.all))

pkgs.BioC.all <- pkgs.BioC.lst <- miniCRAN::pkgDep(pkgs.db$Package[pkgs.BioC], repos=bioc, suggests=FALSE)
pkgs.BioC.lst <- setdiff( pkgs.BioC.lst, pkgs.CRAN.lst ) # Possible risk here: don't double-install packages
cat("pkgs.BioC.all\n")
print(sort(pkgs.BioC.all))

cat("Dependencies:\n")
stated.dependencies <- as.character(c(pkgs.CRAN.lst, pkgs.BioC.lst))
all.dependencies <- setdiff(as.character(c(pkgs.CRAN.all, pkgs.BioC.all)),pkgs.BaseR)
save(stated.dependencies, all.dependencies, file=ve.all.dependencies)

cat("Repository location:",ve.dependencies,"\n")
# Attempt a minimal build of the repository (adding just new packages if we already have the whole thing)
# We won't attempt to delete - cleanup just by rebuilding when cruft gets to be too much.
if ( havePackages() ) {
  pkgs.missing.CRAN <- findMissingPackages(pkgs.CRAN.lst)
  if ( any(sapply(pkgs.missing.CRAN, length)) > 0 ) {
    cat("Updating VE repository to add from CRAN:\n")
    print(union(pkgs.missing.CRAN$src, pkgs.missing.CRAN$bin))
    if ( length(pkgs.missing.CRAN$src) > 0 ) {
      miniCRAN::addPackage(pkgs.missing.CRAN$src, path=ve.dependencies, repos=CRAN.mirror, type=c("source"), deps=FALSE)
    }
    if ( ve.binary.build && length(pkgs.missing.CRAN$bin) > 0 ) {
      miniCRAN::addPackage(pkgs.missing.CRAN$bin, path=ve.dependencies, repos=CRAN.mirror, type=ve.build.type, deps=FALSE)
    }
  }
  pkgs.missing.BioC <- findMissingPackages(pkgs.BioC.lst)
  if ( any(sapply(pkgs.missing.BioC, length)) > 0 ) {
    cat("Updating VE repository to add from BioConductor:\n")
    print(union(pkgs.missing.BioC$src, pkgs.missing.BioC$bin))
    if ( length(pkgs.missing.BioC$src) > 0 ) {
      miniCRAN::addPackage(pkgs.missing.BioC$src, path=ve.dependencies, repos=bioc, type=c("source"), deps=FALSE)
    }
    if ( ve.binary.build && length(pkgs.missing.BioC$bin) > 0 ) {
      miniCRAN::addPackage(pkgs.missing.BioC$bin, path=ve.dependencies, repos=bioc, type=ve.build.type, deps=FALSE)
    }
  }
  cat("Existing VE repository is up to date.\n")
} else {
  cat("Building VE repository from scratch from CRAN packages\n")
  repo.type <- "source"
  if ( ve.binary.build ) repo.type <- c(repo.type,ve.build.type)
  miniCRAN::makeRepo(pkgs.CRAN.lst, path=ve.dependencies, repos=CRAN.mirror, type=repo.type)

  cat("Adding BioConductor packages to new VE repository\n")
  # BioConductor depends on some CRAN packages - no need to download those twice, so deps=FALSE
  miniCRAN::addPackage(pkgs.BioC.lst, path=ve.dependencies, repos=bioc, type=repo.type, deps=FALSE)
}

# Verify the VE Repository with the following independent cross-check of dependencies

# pkgs.VE <- c(pkgs.CRAN.lst, pkgs.BioC.lst)
# ap <- available.packages(repos=ve.deps.url)
# getDependencies <- function(x) {
#   # Used in apply below to avoid a painfully long one-liner
#   # Extracts package names from a standard list of R dependencies
#   strsplit(split=", [ \n]*", paste( (y<-x[c("Package", "Depends", "Imports", "Extends", "LinkingTo")])[!is.na(y)], collapse=", "))
# }
# pkg <- sort(unique(unlist(apply(ap, 1, getDependencies))))
# pkg <- unique(sub("( |\\n)*\\(.*\\)", "", pkg))
# pkg <- setdiff(pkg, c(pkgs.BaseR, "R")) # Kill the BaseR packages from the list of dependencies, as well as dependency on R itself
# if ( length(setdiff(pkgs.VE, pkg)) > 0 ) {
#   cat("Discrepancy:\n")
#   print(setdiff(pkgs.VE, pkg))
# } else if (length(setdiff(pkg, pkgs.VE)) > 0 ) {
#   cat("Discrepancy:\n")
#   print(setdiff(pkg, pkgs.VE))
# } else {
#   cat("VE repository contents are complete\n")
# }
