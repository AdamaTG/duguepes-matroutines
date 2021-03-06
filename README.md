# duguepes-matroutines #

A collection of Matlab routines implementing various tasks related with pattern recognition and computer vision. http://www.cs.uoi.gr/~sfikas

## Useful files ##

* Contents.m -------- Package summary
* buildSegmentation.m -------- Builds a segmentation on a given image. Numerous clustering/segmentation methods are supported.
* gaussianMixBayesian.m -------- Train a GMM w/ Gaussian-Wishart priors using Variational EM.
* gaussianMixBayesianContinuousLp.m -------- Train a GMM w/ the model presented in Sfikas et al. "Edge-preserving spatially-varying mixtures for image segmentation" [CVPR 2008] and the corresponding model in Sfikas et al. "Spatially varying mixtures incorporating line processes for image segmentation" [JMIV 2010].
* buildSegmentation.m

## Requirements ##

Tom Minka's lightspeed package: http://research.microsoft.com/en-us/um/people/minka/software/lightspeed/
