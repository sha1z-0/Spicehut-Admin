import mongoose from 'mongoose';
import dotenv from 'dotenv';

dotenv.config();

// MongoDB Connection
await mongoose.connect(process.env.MONGO_URI)
  .then(() => console.log('✅ MongoDB Connected for seeding'))
  .catch(err => {
    console.error('❌ MongoDB Error:', err);
    process.exit(1);
  });

// VALID LOCATIONS
const LOCATIONS = [
  'Canmore',
  'Comox',
  'Cranbrook',
  'Fort Saskatchewan',
  'Invermere',
  'Ladysmith',
  'Lloydminster',
  'PortAlberni',
  'Tofino',
  'CampbellRiver'
];

// Helper to generate sample tables for a section
function generateSampleTables(sectionId, startNumber, endNumber) {
  const tables = [];
  const shapes = ['circle', 'square', 'rectangle'];
  const statuses = ['available', 'reserved', 'occupied'];
  
  let index = 0;
  for (let i = startNumber; i <= endNumber; i++) {
    const row = Math.floor(index / 3);
    const col = index % 3;
    
    tables.push({
      _id: `t_${sectionId}_${i}`,
      name: `T${i}`,
      number: i,
      capacity: [2, 4, 6, 8][Math.floor(Math.random() * 4)],
      status: statuses[i % statuses.length],
      posX: (col * 120) + 40,
      posY: (row * 120) + 40,
      width: 80,
      height: 80,
      rotation: 0,
      shape: shapes[i % shapes.length],
      sectionId: sectionId,
      currentOrder: [],
      assignedWaiter: null,
      billTotal: null,
      lastModified: new Date()
    });
    
    index++;
  }
  
  return tables;
}

// Sample floor plan template
function createFloorPlanTemplate(location) {
  return {
    type: 'floorplan',
    branchId: location,
    branchName: location,
    sections: [
      {
        id: 'main_hall',
        name: 'Main Hall',
        type: 'main_hall',
        tables: generateSampleTables('main_hall', 1, 12)
      },
      {
        id: 'outdoor',
        name: 'Outdoor Patio',
        type: 'outdoor',
        tables: generateSampleTables('outdoor', 13, 18)
      },
      {
        id: 'vip',
        name: 'VIP Room',
        type: 'vip_room',
        tables: generateSampleTables('vip', 19, 22)
      }
    ],
    lastSynced: new Date(),
    createdAt: new Date(),
    updatedAt: new Date()
  };
}

async function seedTables() {
  try {
    console.log('\n🌱 Starting table seeding for all locations...\n');

    for (const location of LOCATIONS) {
      const collectionName = `tables_${location.replace(/\s+/g, '')}`;
      const collection = mongoose.connection.db.collection(collectionName);

      // Check if floor plan already exists
      const existing = await collection.findOne({ type: 'floorplan' });
      
      if (existing) {
        console.log(`⏭️  ${location}: Floor plan already exists, skipping...`);
        continue;
      }

      // Create floor plan
      const floorPlan = createFloorPlanTemplate(location);
      await collection.insertOne(floorPlan);

      const totalTables = floorPlan.sections.reduce((sum, section) => sum + section.tables.length, 0);
      console.log(`✅ ${location}: Created floor plan with ${floorPlan.sections.length} sections and ${totalTables} tables`);
    }

    console.log('\n🎉 Table seeding completed successfully!\n');
    
    // Display summary
    console.log('📊 Summary:');
    for (const location of LOCATIONS) {
      const collectionName = `tables_${location}`;
      const collection = mongoose.connection.db.collection(collectionName);
      const doc = await collection.findOne({ type: 'floorplan' });
      
      if (doc) {
        const totalTables = doc.sections.reduce((sum, section) => sum + section.tables.length, 0);
        console.log(`   ${location}: ${doc.sections.length} sections, ${totalTables} tables`);
      }
    }
    
    console.log('\n✅ All done!\n');
    process.exit(0);

  } catch (error) {
    console.error('❌ Error seeding tables:', error);
    process.exit(1);
  }
}

// Run seeding immediately
seedTables();
