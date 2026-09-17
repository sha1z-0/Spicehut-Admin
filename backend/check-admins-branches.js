import mongoose from 'mongoose';
import dotenv from 'dotenv';

dotenv.config();

async function checkAdmins() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    const db = mongoose.connection.db;
    const admins = await db.collection('adminusers').find({}).toArray();
    
    console.log('Admins in database:\n');
    admins.forEach((admin, i) => {
      console.log(`${i+1}. ${admin.email}`);
      console.log(`   Branch: ${admin.branch}`);
      console.log(`   Branches: ${JSON.stringify(admin.branches)}`);
      console.log('');
    });
    
    await mongoose.disconnect();
    process.exit(0);
  } catch (e) { 
    console.error(e); 
    process.exit(1); 
  }
}

checkAdmins();
