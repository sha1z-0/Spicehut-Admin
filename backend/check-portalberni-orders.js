import mongoose from 'mongoose';
import dotenv from 'dotenv';

dotenv.config();

async function checkPortAlberniOrders() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('✅ Connected to MongoDB\n');

    const db = mongoose.connection.db;
    
    // List all collections
    const collections = await db.listCollections().toArray();
    console.log('📋 All collections in database:');
    const orderCollections = collections
      .filter(c => c.name.toLowerCase().includes('order'))
      .map(c => c.name)
      .sort();
    orderCollections.forEach(name => console.log(`   - ${name}`));
    
    console.log('\n🔍 Checking Port Alberni collections:\n');
    
    // Check various possible collection names
    const possibleNames = [
      'ordersPortAlberni',
      'ordersPortalberni',
      'ordersportalberni',
      'OrdersPortAlberni',
      'orders_PortAlberni',
      'orders_Port_Alberni'
    ];
    
    for (const name of possibleNames) {
      try {
        const collection = db.collection(name);
        const count = await collection.countDocuments();
        const sample = await collection.findOne();
        console.log(`✅ ${name}: ${count} documents`);
        if (sample) {
          console.log(`   Sample order: ${sample._id || sample.orderId}`);
          console.log(`   Status: ${sample.status}`);
          console.log(`   Date: ${sample.createdAt || sample.dateTime}`);
        }
      } catch (err) {
        console.log(`❌ ${name}: Not found or error`);
      }
    }
    
    // Check recent orders across all order collections
    console.log('\n📊 Recent orders in last 24 hours across all locations:\n');
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    
    for (const collName of orderCollections) {
      try {
        const coll = db.collection(collName);
        const recentCount = await coll.countDocuments({
          createdAt: { $gte: oneDayAgo }
        });
        if (recentCount > 0) {
          console.log(`   ${collName}: ${recentCount} orders`);
          const recent = await coll.find({ createdAt: { $gte: oneDayAgo } })
            .sort({ createdAt: -1 })
            .limit(3)
            .toArray();
          recent.forEach(order => {
            console.log(`      - ${order._id || order.orderId} | ${order.status} | ${order.createdAt}`);
          });
        }
      } catch (err) {
        // Skip
      }
    }
    
    await mongoose.disconnect();
    console.log('\n✅ Done');
    process.exit(0);
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

checkPortAlberniOrders();
