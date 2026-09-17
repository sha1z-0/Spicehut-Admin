const normalizeBranchName = (branch) => {
  if (!branch || typeof branch !== 'string') return branch;
  const trimmed = branch.trim();
  if (trimmed.toLowerCase() === 'nanaimo') return 'Fort Saskatchewan';
  return trimmed;
};

const normalizeLocationForCollection = (location) => {
  if (!location || typeof location !== 'string') return location;
  const trimmed = location.trim();
  if (!trimmed) return trimmed;
  const noSpaces = trimmed.replace(/\s+/g, '');
  
  const locationMap = {
    'portalberni': 'PortAlberni',
    'fortsaskatchewan': 'Nanaimo',
    'campbellriver': 'CampbellRiver',
    'canmore': 'Canmore',
    'comox': 'Comox',
    'cranbrook': 'Cranbrook',
    'invermere': 'Invermere',
    'ladysmith': 'Ladysmith',
    'lloydminster': 'Lloydminster',
    'tofino': 'Tofino'
  };
  
  const lower = noSpaces.toLowerCase();
  return locationMap[lower] || (lower.charAt(0).toUpperCase() + lower.slice(1));
};

const testLocations = ['Comox', 'Port Alberni', 'PortAlberni', 'Fort Saskatchewan', 'Canmore', 'Campbell River', 'CampbellRiver', 'Tofino'];

console.log('Testing branch name normalization:\n');
testLocations.forEach(loc => {
  const normalized = normalizeBranchName(loc);
  const collection = normalizeLocationForCollection(normalized);
  console.log(`Input: "${loc}"`);
  console.log(`  -> Normalized: "${normalized}"`);
  console.log(`  -> Collection: "orders${collection}"\n`);
});
