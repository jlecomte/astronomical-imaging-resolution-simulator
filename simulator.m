# Clear all variables. Very important!
clear all;

# Clear the current figure window
clf;

# Clear the command window
clc;

# Set high accuracy on output for debugging
# (useful to test sensitivity to ADU bit depth)
format long;

try
  pkg load signal
end

################################################################################
# FUNCTIONS

function I = raw_star_intensity_profile(x, x_offset, D, FL, OBS, WL)
  # From https://en.wikipedia.org/wiki/Airy_disk#Obscured_Airy_pattern
  a = 2 * pi * D * (x - x_offset) / (WL * FL);
  I = (1 / (1 - OBS^2)^2) * ((2 * besselj(1, a) ./ a) - (2 * OBS * besselj(1, OBS .* a) ./ a)).^2;
  I = real(I);
endfunction

function G = gaussian_fuzz(x, FL, RMS)
  c = FL * RMS * pi / (180 * 3600);
  G = exp(-(x.^2/(2*c^2)));
endfunction

################################################################################
# PARAMETERS
# You can change these values at will, to test various combinations of equipment
# and observing conditions

# Aperture diameter (in mm, converted to meters)
DIAMETER = 235 * 10^-3;

# Central obstruction.
# Set to 0 for a refractor.
# SCTs have an obstruction of ~ 0.34
# RCs often have an obstruction of ~ 0.45
OBSTRUCTION = 0.35;

# Focal length (in mm, converted to meters)
FOCAL_LENGTH = 2350 * 10^-3;

# Wavelength of light (in nm, converted to meters)
WAVELENGTH = 600 * 10^-9;

# Pixel size (in µm, converted to meters)
# Note: 3.76µm is the pixel size of most ZWO cameras...
PIXEL_SIZE = 3.76 * 10^-6;

# Seeing and guiding RMS, expressed in arc seconds. The value can be obtained by
# measuring (for example in PixInsight, using the DynamicPSF process) the FWHM
# of stars on your images.
#
# Note that this has nothing to do with the total RMS value provided by PHD2.
# Unless you observe from the top of Mauna Kea (so, for most people...), as long
# as you have a somewhat decent mount, the total RMS value given by PHD2 will be
# greatly inferior to the seeing RMS. PHD2 can give an estimation of the
# amplitude of the low frequency component of the seeing. But in the end, its
# effect is minor compared to the high frequency component of the seeing. If you
# measure the FWHM of stars in your images, this value will include both.
FUZZ_RMS_ARCSEC = 1.0;

# Separation, expressed in arc seconds, between the two stars considered here.
STAR_SEPARATION = 2.5;

# How many pixels to look at in this test, e.g., 40 -> +/- 20 pixels
# Adjust up or down to get a better look at the result...
PIXEL_COUNT = 40;

# How many bits the sensor uses to encode light intensity.
# For example, the ZWO ASI1600MM Pro uses a 12 bit ADU.
# But the ZWO ASI2600MM Pro uses a 16 bit ADU.
# This is here anecdotally, because it does not have a big impact on this
# particular simulation scenario, unless I use very low values < 8 bits...
SENSOR_ADC_BITS = 16;

################################################################################
# CONSTANTS USED IN THIS FILE.
# DO NOT MODIFY UNLESS YOU UNDERSTAND WHAT YOU ARE DOING...

MEASUREMENT_POINTS_WITHIN_PIXEL = 100;

SENSOR_ADC_BIT_DEPTH = 2^SENSOR_ADC_BITS;

# "Continuous" variable, covering PIXEL_COUNT pixels
x = -PIXEL_SIZE * PIXEL_COUNT / 2 : PIXEL_SIZE / MEASUREMENT_POINTS_WITHIN_PIXEL : PIXEL_SIZE * PIXEL_COUNT / 2;

# Remove 0 value, if any, because that causes NaN to appear due to values being
# in the denominator in raw_star_intensity_profile. There is probably a better
# solution...
x = x(x~=0);

################################################################################
# SINGLE STAR DIFFRACTION PATTERN

subplot(3, 2, 1);
PLOTDEFAULTS;
title(sprintf('Theoretical diffraction pattern of a single star with a %dmm telescope of %dmm focal length and %d%% obstruction', DIAMETER*1000, FOCAL_LENGTH*1000, OBSTRUCTION*100), 'fontsize', 10);

# Single star centered on the optical axis
single_star_profile = raw_star_intensity_profile(x, 0, DIAMETER, FOCAL_LENGTH, OBSTRUCTION, WAVELENGTH);

hold on
plot(x, single_star_profile);

single_star_fwhm_arcsec = 3600 * 180 * fwhm(x, single_star_profile) / (FOCAL_LENGTH * pi);
text(PIXEL_SIZE, 0.5, sprintf('FWHM is ~ %.*f"', 1, single_star_fwhm_arcsec), 'fontsize', 14);

################################################################################
# DOUBLE STAR DIFFRACTION PATTERN

subplot(3, 2, 2);
PLOTDEFAULTS;
title(sprintf('Theoretical diffraction pattern of a double star separated by %d" seen by the same telescope', STAR_SEPARATION), 'fontsize', 10);

# First star
offset = -FOCAL_LENGTH * (STAR_SEPARATION / 2) * pi / (180 * 3600);
I1 = raw_star_intensity_profile(x, offset, DIAMETER, FOCAL_LENGTH, OBSTRUCTION, WAVELENGTH);

# Second star
offset = -offset;
I2 = raw_star_intensity_profile(x, offset, DIAMETER, FOCAL_LENGTH, OBSTRUCTION, WAVELENGTH);

# Add the two together and plot
double_star_profile = I1 + I2;

hold on
plot(x, double_star_profile);

################################################################################
# Gaussian curve representing the fuzz caused by atmospheric seeing
# and guiding inaccuracies...

G = gaussian_fuzz(x, FOCAL_LENGTH, FUZZ_RMS_ARCSEC);

################################################################################
# SINGLE STAR AFFECTED BY ATMOSPHERIC SEEING / GUIDING INACCURACIES

subplot(3, 2, 3);
PLOTDEFAULTS;
title(sprintf('Single star affected by atmospheric seeing / guiding error of %d" RMS', FUZZ_RMS_ARCSEC), 'fontsize', 10);

# Get real star profile by doing a standard convolution of raw star profile and
# gaussian distribution, and normalize the result so that we can easily compare
# several runs with different values.
real_single_star_profile = conv(single_star_profile, G, "same");
real_single_star_profile = real_single_star_profile ./ max(real_single_star_profile);

hold on
plot(x, real_single_star_profile);

real_single_star_fwhm_arcsec = 3600 * 180 * fwhm(x, real_single_star_profile) / (FOCAL_LENGTH * pi);
text(2 * PIXEL_SIZE, 0.5, sprintf('FWHM is ~ %.*f"', 1, real_single_star_fwhm_arcsec), 'fontsize', 14);

################################################################################
# DOUBLE STAR AFFECTED BY ATMOSPHERIC SEEING / GUIDING INACCURACIES

subplot(3, 2, 4);
PLOTDEFAULTS;
title('The same double star affected by the same amount of atmospheric seeing / guiding error', 'fontsize', 10);

real_double_star_profile = conv(double_star_profile, G, "same");
real_double_star_profile = real_double_star_profile ./ max(real_double_star_profile);

hold on
plot(x, real_double_star_profile);

################################################################################

# "Discrete" variable, covering PIXEL_COUNT pixels, from -PIXEL_COUNT to +PIXEL_COUNT
pixel_indices = -PIXEL_COUNT / 2 : PIXEL_COUNT / 2 - 1;

################################################################################
# REAL SINGLE STAR PERCEIVED BY SENSOR

subplot(3, 2, 5);
title(sprintf('How a sensor with %dµm pixels sees that single star...', PIXEL_SIZE*10^6), 'fontsize', 10);
axis([-PIXEL_COUNT / 2, PIXEL_COUNT / 2, 0, 1], 'ticx', 'nolabel');
set(gca, 'xtick', -PIXEL_COUNT / 2 : PIXEL_COUNT / 2);

# The result, a row vector of pixel values
single_star_pixel_values = [];

pixel_index = 1;
for i = pixel_indices
  start_index = 1 + (pixel_index-1) * MEASUREMENT_POINTS_WITHIN_PIXEL;
  end_index = pixel_index * MEASUREMENT_POINTS_WITHIN_PIXEL;
  y = real_single_star_profile(start_index : end_index);
  single_star_pixel_values(pixel_index) = floor(SENSOR_ADC_BIT_DEPTH * trapz(y) / MEASUREMENT_POINTS_WITHIN_PIXEL)/SENSOR_ADC_BIT_DEPTH;
  pixel_index++;
endfor

hold on
bar(pixel_indices, single_star_pixel_values, 'histc');

################################################################################
# REAL DOUBLE STAR PERCEIVED BY SENSOR

subplot(3, 2, 6);
title('How the same sensor sees the double star...', 'fontsize', 10);
axis([-PIXEL_COUNT / 2, PIXEL_COUNT / 2, 0, 1], 'ticx', 'nolabel');
set(gca, 'xtick', -PIXEL_COUNT / 2 : PIXEL_COUNT / 2);

# The result, a row vector of pixel values
double_star_pixel_values = [];

pixel_index = 1;
for i = pixel_indices
  start_index = 1 + (pixel_index-1) * MEASUREMENT_POINTS_WITHIN_PIXEL;
  end_index = pixel_index * MEASUREMENT_POINTS_WITHIN_PIXEL;
  y = real_double_star_profile(start_index : end_index);
  double_star_pixel_values(pixel_index) = floor(SENSOR_ADC_BIT_DEPTH * trapz(y) / MEASUREMENT_POINTS_WITHIN_PIXEL)/SENSOR_ADC_BIT_DEPTH;
  pixel_index++;
endfor

hold on
bar(pixel_indices, double_star_pixel_values, 'histc');
