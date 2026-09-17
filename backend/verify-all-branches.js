import mongoose from 'mongoose';
import dotenv from 'dotenv';

dotenv.config();

const normalizeLocationForCollection = (location) => {
  if (!location || typeof location !== 'string') return location;
  const trimmed = location.trim();
  if (!trimmed) return trimmed;
  const noSpaces = trimmed.replace(/\s+/g, '');
  
  // Map to exact collection name format to match database
  const locationMap = {
    'portalberni': 'PortAlberni',
    'fortsaskatchewan': 'Nanaimo', // Fort Saskatchewan uses ordersNanaimo collection
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

async function verifyAllBranches() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('✅ Connected to MongoDB\n');

    const db = mongoose.connection.db;
    
    // Get all order collections
    const collections = await db.listCollections().toArray();
    const orderCollections = collections
      .filter(c => c.name.startsWith('orders') && c.name !== 'orders' && c.name !== 'ordercounters')
      .map(c => c.name)
      .sort();
    
    console.log('📋 Database Collections Found:');
    orderCollections.forEach(name => console.log(`   ${name}`));
    console.log('');

    // Test locations that should be used in the app
    const testLocations = [
      'Canmore',
      'Comox',
      'Cranbrook',
      'Fort Saskatchewan',
      'Invermere',
      'Ladysmith',
      'Lloydminster',
      'Port Alberni',
      'PortAlberni',
      'Tofino',
      'Campbell River',
      'CampbellRiver'
    ];

    console.log('🔍 Testing Location Normalization:\n');
    console.log('Location Input → Normalized → Expected Collection');
    console.log('─'.repeat(80));
    
    const results = [];
    for (const location of testLocations) {
      const normalized = normalizeLocationForCollection(location);
      const expectedCollection = `orders${normalized}`;
      const exists = orderCollections.includes(expectedCollection);
      const status = exists ? '✅' : '❌';
      
      console.log(`${status} ${location.padEnd(20)} → ${normalized.padEnd(20)} → ${expectedCollection}`);
      
      if (!exists) {
        results.push({ location, normalized, expectedCollection, status: 'MISSING' });
      } else {
        results.push({ location, normalized, expectedCollection, status: 'OK' });
      }
    }
    
    console.log('\n' + '─'.repeat(80));
    console.log('\n📊 Summary:\n');
    
    const missing = results.filter(r => r.status === 'MISSING');
    const ok = results.filter(r => r.status === 'OK');
    
    console.log(`✅ Correctly Mapped: ${ok.length}`);
    console.log(`❌ Missing Collections: ${missing.length}`);
    
    if (missing.length > 0) {
      console.log('\n⚠️  Collections that don\'t exist in database:');
      missing.forEach(r => {
        console.log(`   - ${r.location} → ${r.expectedCollection}`);
      });
    }
    
    // Check for unmapped collections
    console.log('\n🔎 Checking for unmapped collections in database:\n');
    const mappedCollections = results.filter(r => r.status === 'OK').map(r => r.expectedCollection);
    const unmapped = orderCollections.filter(c => !mappedCollections.includes(c));
    
    if (unmapped.length > 0) {
      console.log('⚠️  Collections in DB that may not be accessible:');
      unmapped.forEach(c => console.log(`   - ${c}`));
    } else {
      console.log('✅ All database collections are properly mapped!');
    }
    
    await mongoose.disconnect();
    console.log('\n✅ Verification complete');
    process.exit(0);
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

verifyAllBranches();
