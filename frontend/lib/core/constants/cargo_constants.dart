/// Air volumetric factor (kg per CBM): the single value shared by the CBM calculator,
/// the PO form and ContainerRequirementEngine. Same as the backend default
/// (`DEFAULT_AIR_VOLUMETRIC_KG_PER_CBM`); saved studies show the backend's own number.
const double kAirVolumetricKgPerCbm = 167.0;

/// Standard trailer internal width in meters for Loading Meters (LDM) calculation.
const double kStandardTrailerWidthM = 2.40;

/// Standard maximum LDM capacity of a standard megatrailer / curtain-sided semi-trailer.
const double kStandardTrailerMaxLdm = 13.6;

/// Default container usable vertical clearance height for non-stackable ocean LCL cargo (meters).
const double kDefaultLclClearanceHeightM = 2.20;

/// Ocean freight metric ton equivalent in kilograms (1 CBM = 1000 kg).
const double kOceanRevenueTonKg = 1000.0;

/// Standard Pallet Presets (dimensions in cm)
const double kEuroPalletLengthCm = 120.0;
const double kEuroPalletWidthCm = 80.0;

const double kStandardPalletLengthCm = 120.0;
const double kStandardPalletWidthCm = 100.0;
