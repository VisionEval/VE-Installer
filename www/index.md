---
layout: category
title: Download
excerpt: "How to download and install VisionEval"
image:
  feature: so-simple-sample-image-4-narrow.jpg
---

## [Get VisionEval Here](installers/VE-installer-windows-R3.5.1.zip) 
**Warning** This Download is approximately **515 Megabytes** (Humongous!)

The link above will download a .zip file containing the following:
 - The VisionEval framework code
 - VE-RSPM, VE-RPAT, VE-GUI, and VE-ScenarioViewer 
 - All necessary R packages
 
The current version of VisionEval requires R 3.5.1 to be installed on your computer.  You can find the <a href="https://cran.r-project.org/bin/windows/base/old/3.5.1/" target="_blank">R 3.5.1 installer for Windows here</a>.

Many users find that <a href="https://www.rstudio.com/products/rstudio/#Desktop" target="_blank">RStudio</a> is a better version of the
standard R interface.  Rstudio is particularly recommended if you plan to clone and explore the
<a target="_blank" href="https://github.com/VisionEval/VisionEval">Visioneval source code from GitHub</a> .

## Install

After installing R 3.5.1 and downloading the VE Installer from the link at the top, unzip the folder to the destination folder of your choice.

To complete the installation and start VisionEval, you can follow one of the following procedures.

1. If you installed R for all users (i.e. as administrator), navigate to the destination folder and follow these steps:
   - Double-click Install-VisionEval.bat and follow the instruction
   - Double-click RunVisionEval.RData to launch R running VisionEval
   - You will see <tt>"Welcome to VisionEval!"</tt> at the end of the R startup message stream if everything went well.

1. If you have not installed R for all users (i.e. without administrator privileges), you can do the steps manually:
   - Start R / RStudio
   - Use File / Change dir... to navigate to the destination folder (where you unzipped the installer)
   - Enter the following instructions one by one in the R command window:

     <tt>source("Install-VisionEval.R")</tt><br/>
     <tt>load("RunVisionEval.Rdata")</tt>

   - You will see <tt>"Welcome to VisionEval!"</tt> at the end of the R startup message stream if everything went well.

Once you have been welcomed to VisionEval, you can follow the instructions under "Running VE Models" on the
<a href="https://github.com/VisionEval/VisionEval/wiki/Getting-Started">Getting Started</a> page.
Your destination folder contains everything you need from the VisionEval "sources" folder.

The installation also creates some convenience functions which will run the model test scenarios or start the VE GUI:
 - <tt>vegui()</tt> to start the GUI (navigate to your destination folder to find the scenario run scripts)
 - <tt>verpat()</tt> for the VERPAT test model
 - <tt>verpat(scenarios=TRUE)</tt> to run multiple scenarios in VERPAT
 - <tt>verpat(baseyear=TRUE)</tt> to run the alternate VERPAT sample scenario
 - <tt>verspm()</tt> for the VERSPM test model
 - <tt>verspm(scenarios=TRUE)</tt> to run multiple scenarios in VERSPM

Questions about VisionEval installation can be directed to Jeremy.Raw or Daniel.Flynn at dot.gov.

The installer and this website were built with the VE-Installer, which is <a target="_blank" href="https://github.com/VisionEval/VE-Installer">available on GitHub</a>

<!-- removed between title and excerpt: <span class="entry-date"><time datetime="{{ post.date | date_to_xmlschema }}">{{ post.date | date: "%B %d, %Y" }}</time></span> -->